#!/usr/bin/env bash
# Integration test: run the full bootstrap (setup_answers schema 2.0,
# 4-agent squad) and assert the produced artifacts.
#
# Usage:
#   ./tests/bootstrap-integration.sh           # Docker mode (debian:12-slim)
#   ./tests/bootstrap-integration.sh --local   # sandboxed local run, no Docker
#
# Both modes execute the same inner script (--inner) against a writable
# copy of the repo: temp VAULT/HERMES_HOME/state, headless install mode,
# auto_start=manual, stages 00→90 (10-obsidian no-ops in headless mode).
#
# Talaria note: stage 50 hard-exits when any check FAILs (OVERALL gate),
# so an unreachable Ollama cannot be "recorded and tolerated". Instead of
# disabling Talaria (which would drop the squad to 3 agents and break the
# 4-bot/4-roster-row assertions), the test serves a mock Ollama endpoint
# on 127.0.0.1:11435 so ollama_tags passes and Talaria stays enabled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="debian:12-slim"
MOCK_OLLAMA_PORT=11435

# ------------------------------------------------------------------
# Copy the repo to a writable workdir, dropping artifacts of previous
# runs (a stale state file or answers file would skip/derail stages).
# ------------------------------------------------------------------
copy_repo() {
    local src="$1" dst="$2"
    mkdir -p "$dst"
    cp -R "$src/." "$dst/"
    rm -rf "$dst/.git" \
        "$dst/hermes-setup.state" \
        "$dst/setup_answers.yaml" \
        "$dst/.env" \
        "$dst/smoke-test-report.json" \
        "$dst/bootstrap/log"
}

# ==================================================================
# INNER: runs inside the container (or the local sandbox).
# Required env: TEST_WORKDIR, TEST_VAULT, TEST_HERMES_HOME
# ==================================================================
run_inner() {
    cd "$TEST_WORKDIR"

    # Mock setup_answers.yaml — schema 2.0. Roster is empty on purpose:
    # per-agent defaults must come from models.lock.yaml. Provider keys
    # are omitted so .env keeps the .env.example placeholders, which the
    # smoke test treats as "not configured" and skips.
    cat > setup_answers.yaml << EOF
version: "2.0"
date: "2026-06-11"
user:
  name: "TestUser"
  email: "test@example.com"
  timezone: "UTC"
team:
  name: "Test Squad"
  domain_blurb: "Integration-test team for the Squad-Mind bootstrap."
paths:
  vault: "$TEST_VAULT"
  hermes_home: "$TEST_HERMES_HOME"
providers:
  mode: "api-keys"
agents:
  roster: {}
  talaria_enabled: true
ollama:
  base_url: "http://127.0.0.1:${MOCK_OLLAMA_PORT}"
lab:
  default_profile: "auto"
projects:
  lab: true
delivery:
  platform: "local-only"
install:
  mode: "headless"
  auto_start: "manual"
EOF

    # Mock Ollama endpoint (see header note)
    MOCK_OLLAMA_PORT="$MOCK_OLLAMA_PORT" python3 - << 'PYEOF' &
import http.server
import json
import os


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"models": []}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


port = int(os.environ['MOCK_OLLAMA_PORT'])
http.server.HTTPServer(('127.0.0.1', port), Handler).serve_forever()
PYEOF
    MOCK_PID=$!
    trap 'kill "$MOCK_PID" 2>/dev/null || true' EXIT

    for _ in $(seq 1 20); do
        if curl -s --max-time 2 "http://127.0.0.1:${MOCK_OLLAMA_PORT}/api/tags" | grep -q '"models"'; then
            break
        fi
        sleep 0.5
    done
    curl -s --max-time 2 "http://127.0.0.1:${MOCK_OLLAMA_PORT}/api/tags" | grep -q '"models"' \
        || { echo "Mock Ollama did not come up on port ${MOCK_OLLAMA_PORT}"; exit 1; }

    echo "Running bootstrap stages 00 → 90 (headless)..."
    ./bootstrap/00-prereqs.sh
    ./bootstrap/10-obsidian.sh      # headless mode: records the step and skips the GUI install
    ./bootstrap/20-hermes-core.sh
    ./bootstrap/30-vault-seed.sh
    ./bootstrap/40-agents-wire.sh
    ./bootstrap/50-smoke-test.sh
    ./bootstrap/60-delivery.sh
    ./bootstrap/70-autostart.sh
    ./bootstrap/80-lab-seed.sh
    ./bootstrap/90-first-run.sh

    echo ""
    echo "Verifying artifacts..."
    FAILURES=0

    check() {
        local desc="$1"
        local cmd="$2"
        if bash -c "$cmd" >/dev/null 2>&1; then
            echo "✅ $desc"
        else
            echo "❌ $desc"
            ((FAILURES++)) || true
        fi
    }

    file_perms() {
        stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
    }
    export -f file_perms

    export TEST_VAULT TEST_HERMES_HOME

    # --- State machine -------------------------------------------------
    check "State file at STEP=9" "grep -q '^STEP=9' '$TEST_WORKDIR/hermes-setup.state'"

    # --- Bots: 4 YAMLs render, parse, models match models.lock.yaml ----
    check "4 bot YAMLs parse and models match models.lock.yaml" "python3 << 'PY'
import os
import sys
import yaml

lock = yaml.safe_load(open('models.lock.yaml'))
hermes_home = os.environ['TEST_HERMES_HOME']
failed = False
for agent_id in ('hermes', 'hephaestus', 'clio', 'talaria'):
    path = os.path.join(hermes_home, 'bots', f'{agent_id}.yaml')
    try:
        bot = yaml.safe_load(open(path))
    except Exception as e:
        print(f'{agent_id}: {e}')
        failed = True
        continue
    expected = str(lock['agents'][agent_id]['model'])
    actual = str(bot.get('model'))
    if actual != expected:
        print(f'{agent_id}: model {actual!r} != lock {expected!r}')
        failed = True
sys.exit(1 if failed else 0)
PY"
    check "talaria.yaml points at the interview Ollama URL" \
        "grep -q '127.0.0.1:${MOCK_OLLAMA_PORT}' '$TEST_HERMES_HOME/bots/talaria.yaml'"

    # --- Vault tree -----------------------------------------------------
    for f in hot.md Memories.md Skills.md AGENT_ROSTER.md; do
        check "Vault brain/$f exists" "test -f '$TEST_VAULT/brain/$f'"
    done
    for agent in Hermes Hephaestus Clio Talaria; do
        check "Vault agents/$agent/SOUL.md exists" "test -f '$TEST_VAULT/agents/$agent/SOUL.md'"
    done
    for f in README.md profiles.md ranker.md poc-validation.md results.md prompts/new-ws-bootstrap.md; do
        check "Lab $f exists" "test -f '$TEST_VAULT/projects/agent-distribution-lab/$f'"
    done
    check "projects/_template/README.md exists" "test -f '$TEST_VAULT/projects/_template/README.md'"
    check "journal/ exists" "test -d '$TEST_VAULT/journal'"

    # --- Rendering ------------------------------------------------------
    check "Zero {{PLACEHOLDER}} markers in vault + bots (excluding *.tmpl)" \
        "! grep -rE --exclude='*.tmpl' '\\{\\{[A-Z_]+\\}\\}' '$TEST_VAULT' '$TEST_HERMES_HOME/bots'"
    check "AGENT_ROSTER.md has 4 agent rows" \
        "test \"\$(grep -c '| active |' '$TEST_VAULT/brain/AGENT_ROSTER.md')\" -eq 4"

    # --- Config deep-merge ----------------------------------------------
    check "config.yaml has curator.enabled + kanban.dispatch_in_gateway" "python3 << 'PY'
import os
import sys
import yaml

cfg = yaml.safe_load(open(os.path.join(os.environ['TEST_HERMES_HOME'], 'config.yaml')))
ok = (cfg.get('curator', {}).get('enabled') is True
      and cfg.get('kanban', {}).get('dispatch_in_gateway') is True)
sys.exit(0 if ok else 1)
PY"

    # --- Symlink wiring ---------------------------------------------------
    check "agents/Hermes/projects symlink resolves to the projects tree" \
        "test -L '$TEST_VAULT/agents/Hermes/projects' && test -f '$TEST_VAULT/agents/Hermes/projects/agent-distribution-lab/README.md'"
    check "agents/Hephaestus/projects/agent-distribution-lab resolves" \
        "test -f '$TEST_VAULT/agents/Hephaestus/projects/agent-distribution-lab/README.md'"

    # --- Permissions / env -------------------------------------------------
    check "Hermes runtime permissions 700" "test \"\$(file_perms '$TEST_HERMES_HOME')\" = 700"
    check ".env exists" "test -f '$TEST_WORKDIR/.env'"
    check ".env permissions 600" "test \"\$(file_perms '$TEST_WORKDIR/.env')\" = 600"
    check "Smoke test report written" "test -f '$TEST_WORKDIR/smoke-test-report.json'"

    echo ""
    if [[ "$FAILURES" -eq 0 ]]; then
        echo "=== Integration test (inner): PASS ==="
        exit 0
    else
        echo "=== Integration test (inner): FAIL ($FAILURES failures) ==="
        exit 1
    fi
}

if [[ "${1:-}" == "--inner" ]]; then
    run_inner
fi

echo "=== Squad-Mind Bootstrap Integration Test ==="
echo "Repo: $REPO_ROOT"

# ==================================================================
# LOCAL MODE: sandboxed run on this machine (no Docker)
# ==================================================================
if [[ "${1:-}" == "--local" ]]; then
    echo "Mode: local sandbox"
    SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hermes-itest.XXXXXX")"
    trap 'rm -rf "$SANDBOX"' EXIT

    copy_repo "$REPO_ROOT" "$SANDBOX/work"

    # The stages need python3 + pyyaml; use a throwaway venv if missing.
    if ! python3 -c 'import yaml' 2>/dev/null; then
        echo "pyyaml not importable — creating temp venv..."
        python3 -m venv "$SANDBOX/venv"
        "$SANDBOX/venv/bin/pip" install --quiet pyyaml
        export PATH="$SANDBOX/venv/bin:$PATH"
    fi

    set +e
    TEST_WORKDIR="$SANDBOX/work" \
    TEST_VAULT="$SANDBOX/vault/Home-Brain" \
    TEST_HERMES_HOME="$SANDBOX/hermes" \
        bash "$SANDBOX/work/tests/bootstrap-integration.sh" --inner
    RC=$?
    set -e

    cp -f "$SANDBOX/work/smoke-test-report.json" "$REPO_ROOT/smoke-test-report.json" 2>/dev/null || true

    if [[ "$RC" -eq 0 ]]; then
        echo "=== Integration test: PASS (local) ==="
    else
        echo "=== Integration test: FAIL (local) ==="
    fi
    exit "$RC"
fi

# ==================================================================
# DOCKER MODE (default — used by CI)
# ==================================================================
echo "Mode: docker ($IMAGE)"
CONTAINER_NAME="hermes-bootstrap-test-$$"

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

docker run -d --name "$CONTAINER_NAME" \
    -v "$REPO_ROOT:/workspace:ro" \
    "$IMAGE" \
    sleep 3600

docker exec "$CONTAINER_NAME" bash -c '
    apt-get update -qq
    apt-get install -y -qq curl bash git python3 python3-yaml procps net-tools ca-certificates 2>/dev/null
'

# The repo is mounted read-only; bootstrap needs a writable workdir.
docker exec "$CONTAINER_NAME" bash -c '
    mkdir -p /work
    cp -R /workspace/. /work/
    rm -rf /work/.git /work/hermes-setup.state /work/setup_answers.yaml \
        /work/.env /work/smoke-test-report.json /work/bootstrap/log
'

set +e
docker exec \
    -e TEST_WORKDIR=/work \
    -e TEST_VAULT=/root/Documents/Home-Brain \
    -e TEST_HERMES_HOME=/root/.hermes \
    "$CONTAINER_NAME" bash /work/tests/bootstrap-integration.sh --inner
RC=$?
set -e

# Surface the smoke report for CI artifact upload
docker cp "$CONTAINER_NAME:/work/smoke-test-report.json" "$REPO_ROOT/smoke-test-report.json" 2>/dev/null || true

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo ""
if [[ "$RC" -eq 0 ]]; then
    echo "=== Integration test: PASS ==="
else
    echo "=== Integration test: FAIL ==="
fi
exit "$RC"
