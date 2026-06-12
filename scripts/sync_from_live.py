#!/usr/bin/env python3
"""sync_from_live.py — drift control between Squad-Mind templates and a live deployment.

Two modes:
  --live  Compare this machine's live hermes deployment against the repo
          templates + models.lock.yaml. 5 check groups: models, config,
          bots, vault-structure, proxy.
  --ci    Static checks only (no live-system access). Safe for CI.

Findings are {group, severity, key, live_value, template_value,
suggested_action}. severity is "drift" (actionable mismatch) or "info"
(FYI / candidate). Exit 1 if any unsuppressed drift remains, else 0.

Suppression: .syncignore at the repo root — `group:key` fnmatch patterns,
one per line, `#` comments.
"""

import argparse
import difflib
import fnmatch
import glob
import json
import os
import plistlib
import re
import subprocess
import sys

try:
    import yaml
except ImportError:
    sys.exit("sync_from_live.py: PyYAML is required (pip install pyyaml)")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser("~")
# Live-deployment paths. Override via env when your layout differs from the
# kit's defaults (e.g. a vault at a different path, or the lab project nested
# under a parent initiative).
HERMES_HOME = os.environ.get("SYNC_LIVE_HERMES_HOME", os.path.join(HOME, ".hermes"))
VAULT = os.environ.get("SYNC_LIVE_VAULT", os.path.join(HOME, "Documents", "Home-Brain"))
LAUNCH_AGENTS = os.path.join(HOME, "Library", "LaunchAgents")

# Governance docs: template tree is rooted at projects/agent-distribution-lab/.
# Fresh installs keep the same layout live; set SYNC_LIVE_GOV_ROOT when your
# vault nests the lab under a parent project.
GOV_TEMPLATE_ROOT = "projects/agent-distribution-lab"
GOV_LIVE_ROOT = os.environ.get("SYNC_LIVE_GOV_ROOT", GOV_TEMPLATE_ROOT)
GOV_DOCS = ["profiles.md", "ranker.md", "poc-validation.md", "prompts/new-ws-bootstrap.md"]

VAR_RE = re.compile(r"\{\{([A-Z_]+)\}\}")


def finding(group, severity, key, live_value, template_value, suggested_action):
    return {
        "group": group,
        "severity": severity,
        "key": key,
        "live_value": live_value,
        "template_value": template_value,
        "suggested_action": suggested_action,
    }


def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)


def render(text, mapping):
    """render_template semantics: pure string replacement of {{KEY}}."""
    for key, val in mapping.items():
        text = text.replace("{{" + key + "}}", str(val))
    return text


def dummy_render(text):
    """Replace every remaining {{VAR}} with a parse-safe dummy value."""
    def sub(m):
        var = m.group(1)
        return "0" if var.endswith("_PORT") else "dummy-" + var.lower().replace("_", "-")
    return VAR_RE.sub(sub, text)


def flatten(obj, prefix=""):
    """Flatten nested dicts/lists to {dotted.path[i]: leaf_value}."""
    out = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            path = f"{prefix}.{k}" if prefix else str(k)
            out.update(flatten(v, path))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            out.update(flatten(v, f"{prefix}[{i}]"))
    else:
        out[prefix] = obj
    return out


def lock():
    return load_yaml(os.path.join(REPO, "models.lock.yaml"))


# ------------------------------------------------------------------
# --live group 1: models
# ------------------------------------------------------------------
def check_models(findings):
    lk = lock()
    for agent, spec in lk["agents"].items():
        port = spec.get("port")
        # Launchd plists are the running truth.
        if port is not None:
            plist_path = os.path.join(LAUNCH_AGENTS, f"ai.hermes.proxy-{agent}.plist")
            if not os.path.exists(plist_path):
                findings.append(finding(
                    "models", "drift", f"plist.{agent}", "missing",
                    f"ai.hermes.proxy-{agent}.plist", "deploy"))
            else:
                with open(plist_path, "rb") as f:
                    args = plistlib.load(f).get("ProgramArguments", [])
                live = {}
                for flag, name in (("--provider", "cli"), ("--model", "model"), ("--port", "port")):
                    if flag in args:
                        live[name] = args[args.index(flag) + 1]
                for field in ("cli", "model", "port"):
                    lock_val = spec.get(field)
                    live_val = live.get(field)
                    if str(live_val) != str(lock_val):
                        findings.append(finding(
                            "models", "drift", f"plist.{agent}.{field}",
                            live_val, lock_val,
                            "backport (plists are the running truth — update models.lock.yaml)"))
        # Live bot YAML vs lock (the plist wins ties; bot YAMLs have drifted).
        bot_path = os.path.join(HERMES_HOME, "bots", f"{agent}.yaml")
        if not os.path.exists(bot_path):
            continue  # absence is reported by the bots group
        bot = load_yaml(bot_path) or {}
        bot_port = (bot.get("proxy") or {}).get("port")
        pairs = [("cli", bot.get("cli")), ("model", bot.get("model")), ("port", bot_port)]
        if spec.get("runtime"):
            pairs = [("model", bot.get("model")), ("runtime", bot.get("runtime"))]
        for field, live_val in pairs:
            lock_val = spec.get(field)
            if str(live_val) != str(lock_val):
                findings.append(finding(
                    "models", "drift", f"bots.{agent}.{field}", live_val, lock_val,
                    "deploy (plist is the tiebreaker — re-render bot yaml from models.lock.yaml)"))


# ------------------------------------------------------------------
# --live group 2: config
# ------------------------------------------------------------------
def check_config(findings):
    lk = lock()
    overlay_path = os.path.join(REPO, "templates", "runtime", "hermes", "config.overlay.yaml")
    with open(overlay_path) as f:
        raw = f.read()
    # Templated leaves resolvable from the lock are rendered with lock values
    # and compared concretely; any other templated leaf is presence-only.
    raw_leaves = flatten(yaml.safe_load(raw))
    rendered = dummy_render(render(raw, {
        "HERMES_MODEL": lk["agents"]["hermes"]["model"],
        "HERMES_PORT": lk["agents"]["hermes"]["port"],
    }))
    overlay = flatten(yaml.safe_load(rendered))
    live = flatten(load_yaml(os.path.join(HERMES_HOME, "config.yaml")) or {})

    for key, tval in overlay.items():
        templated = "{{" in str(raw_leaves.get(key, ""))
        if key not in live:
            findings.append(finding("config", "drift", key, "absent", tval,
                                    "deploy (re-run bootstrap stage 20 overlay merge)"))
            continue
        if "dummy-" in str(tval):
            continue  # unresolvable templated value: presence check only
        lval = live[key]
        if str(lval) != str(tval):
            action = "backport or ignore"
            if templated:
                action = "ignore if intentional (templated from models.lock.yaml)"
            findings.append(finding("config", "drift", key, lval, tval, action))

    live_ver = live.get("_config_version")
    lock_ver = lk["hermes_agent"]["config_version"]
    if live_ver is not None:
        if int(live_ver) < int(lock_ver):
            findings.append(finding("config", "drift", "_config_version", live_ver, lock_ver,
                                    "deploy (live hermes-agent config schema is behind the lock)"))
        elif int(live_ver) > int(lock_ver):
            findings.append(finding("config", "info", "_config_version", live_ver, lock_ver,
                                    "schema moved ahead — review overlay"))


# ------------------------------------------------------------------
# --live group 3: bots
# ------------------------------------------------------------------
def check_bots(findings):
    tmpl_dir = os.path.join(REPO, "templates", "runtime", "hermes", "bots")
    for tmpl in sorted(glob.glob(os.path.join(tmpl_dir, "*.yaml.tmpl"))):
        agent = os.path.basename(tmpl)[: -len(".yaml.tmpl")]
        with open(tmpl) as f:
            rendered = yaml.safe_load(dummy_render(f.read()))
        live_path = os.path.join(HERMES_HOME, "bots", f"{agent}.yaml")
        if not os.path.exists(live_path):
            findings.append(finding("bots", "info", f"{agent}.yaml", "absent",
                                    "present in templates", "deploy"))
            continue
        live = load_yaml(live_path) or {}
        tkeys, lkeys = set(flatten(rendered)), set(flatten(live))
        for key in sorted(lkeys - tkeys):
            findings.append(finding("bots", "drift", f"{agent}.{key}",
                                    "present", "absent", "backport"))
        for key in sorted(tkeys - lkeys):
            findings.append(finding("bots", "info", f"{agent}.{key}",
                                    "absent", "present", "deploy"))
        # Persona path case: compare the vault-relative tail case-sensitively.
        t_persona, l_persona = rendered.get("persona", ""), live.get("persona", "")
        t_tail = t_persona.split("/agents/")[-1] if "/agents/" in t_persona else t_persona
        l_tail = l_persona.split("/agents/")[-1] if "/agents/" in l_persona else l_persona
        if t_tail.lower() == l_tail.lower() and t_tail != l_tail:
            findings.append(finding("bots", "drift", f"{agent}.persona", l_persona,
                                    f".../agents/{t_tail}",
                                    "deploy (case mismatch — re-render bot yaml)"))


# ------------------------------------------------------------------
# --live group 4: vault-structure
# ------------------------------------------------------------------
def _vault_inventory(root, strip_tmpl=False):
    paths = set()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for name in filenames:
            if name.startswith(".") or name == ".gitkeep":
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), root)
            if strip_tmpl and rel.endswith(".tmpl"):
                rel = rel[: -len(".tmpl")]
            paths.add(rel)
    return paths


def _doc_shape(path):
    """(frontmatter keys, '## ' heading list) of a markdown doc."""
    with open(path) as f:
        text = f.read()
    fm_keys = []
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            fm = yaml.safe_load(text[4:end])
            if isinstance(fm, dict):
                fm_keys = sorted(fm.keys())
    headings = [l.strip() for l in text.splitlines() if l.startswith("## ")]
    return fm_keys, headings


def check_vault_structure(findings):
    tmpl_root = os.path.join(REPO, "templates", "vault")
    tmpl = _vault_inventory(tmpl_root, strip_tmpl=True)
    live = _vault_inventory(VAULT)
    # Map the live governance subtree onto the template's lab root.
    live_mapped = {
        GOV_TEMPLATE_ROOT + p[len(GOV_LIVE_ROOT):] if p.startswith(GOV_LIVE_ROOT + "/") else p
        for p in live
    }
    for path in sorted(tmpl - live_mapped):
        findings.append(finding("vault-structure", "info", path, "absent", "present", "deploy"))
    for path in sorted(live_mapped - tmpl):
        findings.append(finding("vault-structure", "info", path, "present", "absent",
                                "backport candidate"))
    # Governance docs: frontmatter keys + '## ' headings only (body = run data).
    for doc in GOV_DOCS:
        tpath = os.path.join(tmpl_root, GOV_TEMPLATE_ROOT, doc)
        lpath = os.path.join(VAULT, GOV_LIVE_ROOT, doc)
        if not os.path.exists(lpath):
            findings.append(finding("vault-structure", "info", f"governance/{doc}", "absent",
                                    "present", "deploy"))
            continue
        t_fm, t_head = _doc_shape(tpath)
        l_fm, l_head = _doc_shape(lpath)
        if t_fm != l_fm:
            findings.append(finding("vault-structure", "drift", f"governance/{doc}:frontmatter",
                                    l_fm, t_fm, "backport"))
        if t_head != l_head:
            diff = list(difflib.unified_diff(t_head, l_head, lineterm="", n=0))[3:]
            findings.append(finding("vault-structure", "drift", f"governance/{doc}:headings",
                                    [l for l in diff if l.startswith("+")],
                                    [l for l in diff if l.startswith("-")], "backport"))


# ------------------------------------------------------------------
# --live group 5: proxy
# ------------------------------------------------------------------
def _pkg_version(root):
    try:
        with open(os.path.join(root, "package.json")) as f:
            return json.load(f).get("version")
    except OSError:
        return None


def _git_head(root):
    try:
        return subprocess.run(["git", "-C", root, "rev-parse", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def check_proxy(findings):
    repo_proxy = os.path.join(REPO, "tools", "llm-cli-proxy")
    link = os.path.join(HERMES_HOME, "llm-cli-proxy-link")
    if not os.path.exists(link):
        findings.append(finding("proxy", "drift", "llm-cli-proxy-link", "missing",
                                "symlink to deployed proxy", "deploy"))
        return
    deployed = os.path.realpath(link)
    if not os.path.isdir(repo_proxy):
        findings.append(finding("proxy", "info", "tools/llm-cli-proxy", "n/a",
                                "clone missing in repo — cannot compare", "ignore"))
    else:
        repo_ver, dep_ver = _pkg_version(repo_proxy), _pkg_version(deployed)
        if repo_ver != dep_ver:
            findings.append(finding("proxy", "drift", "package.version", dep_ver, repo_ver,
                                    "deploy or backport"))
        repo_head, dep_head = _git_head(repo_proxy), _git_head(deployed)
        if repo_head and dep_head and repo_head != dep_head:
            findings.append(finding("proxy", "drift", "git.head", dep_head, repo_head,
                                    "deploy or backport"))
    # talariaProvider must exist in the deployed proxy source/dist.
    present = False
    for sub in ("src", "dist"):
        for dirpath, dirnames, filenames in os.walk(os.path.join(deployed, sub)):
            dirnames[:] = [d for d in dirnames if d != "node_modules"]
            for name in filenames:
                if name.endswith((".ts", ".js")):
                    try:
                        with open(os.path.join(dirpath, name), errors="ignore") as f:
                            if "talariaProvider" in f.read():
                                present = True
                    except OSError:
                        pass
    if not present:
        findings.append(finding("proxy", "drift", "talariaProvider", "absent",
                                "required in deployed src/dist", "deploy"))


# ------------------------------------------------------------------
# --ci static checks
# ------------------------------------------------------------------
def ci_check_bot_templates(findings):
    """(a) Every lock agent has a bot template whose defaults header matches the lock."""
    lk = lock()
    tmpl_dir = os.path.join(REPO, "templates", "runtime", "hermes", "bots")
    for agent, spec in lk["agents"].items():
        tmpl = os.path.join(tmpl_dir, f"{agent}.yaml.tmpl")
        if not os.path.exists(tmpl):
            findings.append(finding("models", "drift", f"template.{agent}", "n/a",
                                    f"missing bots/{agent}.yaml.tmpl", "backport"))
            continue
        header = {}
        with open(tmpl) as f:
            for line in f:
                m = re.match(rf"#\s*\({agent}:\s*(.+)\)\s*$", line.strip())
                if m:
                    for tok in m.group(1).split(","):
                        tok = tok.strip()
                        if "=" in tok:
                            k, v = tok.split("=", 1)
                            header[k.strip()] = v.strip()
                        elif tok == "no proxy":
                            header["port"] = "None"
                    break
        if not header:
            findings.append(finding("models", "drift", f"template.{agent}.header", "n/a",
                                    "no parseable defaults header comment", "backport"))
            continue
        for field in ("cli", "model", "port", "runtime", "temperature"):
            if field in header and field in spec or field in header and spec.get(field) is None:
                if str(header[field]) != str(spec.get(field)):
                    findings.append(finding(
                        "models", "drift", f"template.{agent}.{field}",
                        "n/a", f"header={header[field]} lock={spec.get(field)}",
                        "backport (update the template defaults header)"))


def ci_check_template_vars(findings):
    """(b) Every {{VAR}} in templates/ is supplied by some bootstrap render call."""
    tmpl_vars = set()
    for dirpath, _, filenames in os.walk(os.path.join(REPO, "templates")):
        for name in filenames:
            try:
                with open(os.path.join(dirpath, name), errors="ignore") as f:
                    tmpl_vars.update(VAR_RE.findall(f.read()))
            except OSError:
                pass
    bootstrap_text = ""
    for path in glob.glob(os.path.join(REPO, "bootstrap", "*.sh")):
        with open(path) as f:
            bootstrap_text += f.read()
    for var in sorted(tmpl_vars):
        if not re.search(rf"(\b{var}=|['\"]{var}['\"])", bootstrap_text):
            findings.append(finding("vars", "drift", var, "n/a",
                                    "{{%s}} not supplied by any bootstrap render call" % var,
                                    "backport (wire the variable into the rendering stage)"))


def ci_check_interview(findings):
    """(c) INTERVIEW.md's example setup_answers block parses and is schema 2.0."""
    with open(os.path.join(REPO, "INTERVIEW.md")) as f:
        text = f.read()
    m = re.search(r"## Output Schema.*?```yaml\n(.*?)```", text, re.S)
    if not m:
        findings.append(finding("interview", "drift", "example-block", "n/a",
                                "no ```yaml block under '## Output Schema'", "backport"))
        return
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        findings.append(finding("interview", "drift", "example-block", "n/a",
                                f"does not parse as YAML: {e}", "backport"))
        return
    if data.get("version") != "2.0":
        findings.append(finding("interview", "drift", "version", "n/a",
                                f"expected \"2.0\", got {data.get('version')!r}", "backport"))
    for key in ("user", "team", "paths", "providers", "agents", "lab", "delivery", "install"):
        if key not in data:
            findings.append(finding("interview", "drift", f"required-key.{key}", "n/a",
                                    "missing from example setup_answers block", "backport"))


def ci_check_overlay(findings):
    """(d) config.overlay.yaml parses after dummy render and has the kit keys."""
    path = os.path.join(REPO, "templates", "runtime", "hermes", "config.overlay.yaml")
    with open(path) as f:
        raw = f.read()
    try:
        overlay = yaml.safe_load(dummy_render(raw)) or {}
    except yaml.YAMLError as e:
        findings.append(finding("config", "drift", "overlay-parse", "n/a",
                                f"config.overlay.yaml does not parse after render: {e}",
                                "backport"))
        return
    flat = flatten(overlay)
    for key in ("curator.enabled", "kanban.dispatch_in_gateway"):
        if key not in flat:
            findings.append(finding("config", "drift", key, "n/a",
                                    "missing from config.overlay.yaml", "backport"))


# ------------------------------------------------------------------
# Suppression + output
# ------------------------------------------------------------------
def load_syncignore():
    patterns = []
    path = os.path.join(REPO, ".syncignore")
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    patterns.append(line)
    return patterns


def split_suppressed(findings, patterns):
    kept, suppressed = [], []
    for f in findings:
        tag = f"{f['group']}:{f['key']}"
        hit = any(tag == p or fnmatch.fnmatch(tag, p) for p in patterns)
        (suppressed if hit else kept).append(f)
    return kept, suppressed


def emit(findings, suppressed, mode, fmt):
    drift = sum(1 for f in findings if f["severity"] == "drift")
    info = sum(1 for f in findings if f["severity"] == "info")
    summary = {"mode": mode, "drift": drift, "info": info, "suppressed": len(suppressed)}
    if fmt == "json":
        print(json.dumps({"summary": summary, "findings": findings,
                          "suppressed": suppressed}, indent=2, default=str))
    else:
        if findings:
            rows = [("GROUP", "SEV", "KEY", "ACTION", "LIVE", "TEMPLATE")]
            for f in findings:
                rows.append((f["group"], f["severity"], f["key"],
                             str(f["suggested_action"])[:40],
                             str(f["live_value"])[:40], str(f["template_value"])[:40]))
            widths = [max(len(r[i]) for r in rows) for i in range(6)]
            for r in rows:
                print("  ".join(c.ljust(w) for c, w in zip(r, widths)).rstrip())
        print(f"summary: mode={mode} drift={drift} info={info} "
              f"suppressed={len(suppressed)}")
    return 1 if drift else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--live", action="store_true", help="compare against the live deployment")
    mode.add_argument("--ci", action="store_true", help="static checks only (no live access)")
    ap.add_argument("--format", choices=["text", "json"], default="text")
    args = ap.parse_args()

    findings = []
    if args.live:
        check_models(findings)
        check_config(findings)
        check_bots(findings)
        check_vault_structure(findings)
        check_proxy(findings)
    else:
        ci_check_bot_templates(findings)
        ci_check_template_vars(findings)
        ci_check_interview(findings)
        ci_check_overlay(findings)
        findings.append(finding(
            "future-work", "info", "hermes-agent-schema", "n/a",
            "pip-install hermes-agent and diff its default config schema "
            "against config.overlay.yaml — skipped in --ci for now", "ignore"))

    kept, suppressed = split_suppressed(findings, load_syncignore())
    sys.exit(emit(kept, suppressed, "live" if args.live else "ci", args.format))


if __name__ == "__main__":
    main()
