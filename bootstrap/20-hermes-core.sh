#!/usr/bin/env bash
# Stage 2: Install Hermes Agent Runtime (~/.hermes)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 2

info "=== Stage 2: Hermes Runtime Setup ==="

require_answers_v2 "setup_answers.yaml"

HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

info "Hermes home: $HERMES_HOME"

# ------------------------------------------------------------------
# Create runtime skeleton
# ------------------------------------------------------------------
mkdir -p "$HERMES_HOME"/{bots,profiles,bin,scripts,logs}
chmod 700 "$HERMES_HOME"

# Copy runtime helper scripts (templates with {{VARS}} are rendered by
# stage 40, not copied raw)
if [[ -d "templates/runtime/hermes/scripts" ]]; then
    find "templates/runtime/hermes/scripts" -type f ! -name "*.tmpl" -exec cp {} "$HERMES_HOME/scripts/" \;
    chmod +x "$HERMES_HOME/scripts/"*.sh 2>/dev/null || true
    info "Copied runtime scripts to $HERMES_HOME/scripts/"
fi

# ------------------------------------------------------------------
# Build llm-cli-proxy from the vendored submodule (cli-proxy modes)
# ------------------------------------------------------------------
# The tools/llm-cli-proxy submodule (fork pinned to squad-mind, see
# patches/) is built locally and exposed via the llm-cli-proxy-link
# symlink that stage 70's PROXY_DIST default resolves through. If the
# submodule isn't checked out, fall back to the documented global
# install (npm install -g llm-cli-proxy).
PROVIDER_MODE=$(read_yaml_key setup_answers.yaml "providers.mode" || echo "cli-proxy")
PROXY_SRC="tools/llm-cli-proxy"

if [[ "$PROVIDER_MODE" == "cli-proxy" || "$PROVIDER_MODE" == "mixed" ]]; then
    if [[ -f "$PROXY_SRC/package.json" ]]; then
        info "Building llm-cli-proxy from submodule ($PROXY_SRC)..."
        (cd "$PROXY_SRC" && npm ci && npm run build)
        ln -sfn "$(cd "$PROXY_SRC" && pwd)" "$HERMES_HOME/llm-cli-proxy-link"
        PROXY_DIST="$HERMES_HOME/llm-cli-proxy-link/dist/index.js"
        export PROXY_DIST
        info "Proxy built: PROXY_DIST=$PROXY_DIST"
    elif command -v llm-cli-proxy >/dev/null 2>&1; then
        info "Submodule not checked out; using global llm-cli-proxy: $(command -v llm-cli-proxy)"
    else
        info "Submodule not checked out — falling back to: npm install -g llm-cli-proxy"
        npm install -g llm-cli-proxy
    fi
fi

# ------------------------------------------------------------------
# Deep-merge kit-owned config overlay into config.yaml
# ------------------------------------------------------------------
# Hermes model/port: setup_answers agents table wins, models.lock.yaml is
# the fallback (single source of truth for defaults).
HERMES_MODEL=$(read_yaml_key setup_answers.yaml "agents.roster.hermes.model" \
    || read_yaml_key models.lock.yaml "agents.hermes.model" \
    || echo "claude-opus-4-7")
HERMES_PORT=$(read_yaml_key setup_answers.yaml "agents.roster.hermes.port" \
    || read_yaml_key models.lock.yaml "agents.hermes.port" \
    || echo "3456")

OVERLAY_SRC="templates/runtime/hermes/config.overlay.yaml"
require_file "$OVERLAY_SRC"

OVERLAY_RENDERED=$(mktemp)
render_template "$OVERLAY_SRC" "$OVERLAY_RENDERED" \
    "HERMES_MODEL=$HERMES_MODEL" \
    "HERMES_PORT=$HERMES_PORT"

OVERLAY_RENDERED="$OVERLAY_RENDERED" HERMES_HOME="$HERMES_HOME" python3 << 'PYEOF'
import os
import yaml

overlay_path = os.environ['OVERLAY_RENDERED']
config_path = os.path.join(os.environ['HERMES_HOME'], 'config.yaml')

with open(overlay_path) as f:
    overlay = yaml.safe_load(f) or {}

base = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        base = yaml.safe_load(f) or {}


def deep_merge(dst, src):
    """Recursive dict merge — overlay (src) wins on conflicts."""
    for key, val in src.items():
        if isinstance(val, dict) and isinstance(dst.get(key), dict):
            deep_merge(dst[key], val)
        else:
            dst[key] = val
    return dst


merged = deep_merge(base, overlay)

with open(config_path, 'w') as f:
    yaml.safe_dump(merged, f, default_flow_style=False, sort_keys=False)

print(f"Merged config overlay into {config_path}")
PYEOF

rm -f "$OVERLAY_RENDERED"
info "Config overlay merged (hermes model=$HERMES_MODEL port=$HERMES_PORT)"

info "Runtime permissions: $(ls -ld "$HERMES_HOME" | awk '{print $1}')"

set_step 2
info "=== Stage 2 complete ==="
