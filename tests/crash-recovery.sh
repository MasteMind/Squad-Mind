#!/usr/bin/env bash
# Crash-recovery test: interrupt bootstrap and verify resume works
# (setup_answers schema 2.0; stage 8 is 80-lab-seed.sh).
#
# Usage:
#   ./tests/crash-recovery.sh           # Docker mode (debian:12-slim)
#   ./tests/crash-recovery.sh --local   # sandboxed local run, no Docker
#
# Fixture runs the 3-agent path (talaria_enabled: false, no ollama key)
# so the smoke test passes without any reachable Ollama endpoint —
# stage 50 hard-exits on any FAIL, which would block the resume phases.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="debian:12-slim"

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

    # Mock setup_answers.yaml — schema 2.0, minimal 3-agent squad.
    cat > setup_answers.yaml << EOF
version: "2.0"
date: "2026-06-11"
user:
  name: "CrashTest"
  email: "crash@example.com"
  timezone: "UTC"
team:
  name: "Crash Squad"
paths:
  vault: "$TEST_VAULT"
  hermes_home: "$TEST_HERMES_HOME"
providers:
  mode: "api-keys"
agents:
  roster: {}
  talaria_enabled: false
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

    echo "Phase 1: Run stages 0-2"
    ./bootstrap/00-prereqs.sh
    ./bootstrap/10-obsidian.sh
    ./bootstrap/20-hermes-core.sh

    echo "Phase 2: Verify state is at STEP=2"
    grep -q "^STEP=2$" hermes-setup.state

    echo "Phase 3: Re-run from stage 0 — stages 0-2 should be skipped"
    OUTPUT=$(
        ./bootstrap/00-prereqs.sh 2>&1
        ./bootstrap/10-obsidian.sh 2>&1
        ./bootstrap/20-hermes-core.sh 2>&1
    )
    if echo "$OUTPUT" | grep -q "already complete. Skipping"; then
        echo "✅ Idempotency: stages 0-2 correctly skipped"
    else
        echo "❌ Idempotency: stages 0-2 were not skipped"
        echo "$OUTPUT"
        exit 1
    fi

    echo "Phase 4: Run remaining stages to completion"
    ./bootstrap/30-vault-seed.sh
    ./bootstrap/40-agents-wire.sh
    ./bootstrap/50-smoke-test.sh
    ./bootstrap/60-delivery.sh
    ./bootstrap/70-autostart.sh
    ./bootstrap/80-lab-seed.sh
    ./bootstrap/90-first-run.sh

    echo "Phase 5: Verify final state"
    grep -q "^STEP=9$" hermes-setup.state

    # 3-agent path sanity: talaria disabled → 3 bots, 3 roster rows
    BOT_COUNT=$(ls "$TEST_HERMES_HOME/bots/"*.yaml | wc -l | tr -d ' ')
    if [[ "$BOT_COUNT" -ne 3 ]]; then
        echo "❌ Expected 3 bot YAMLs (talaria disabled), found $BOT_COUNT"
        exit 1
    fi
    ROW_COUNT=$(grep -c '| active |' "$TEST_VAULT/brain/AGENT_ROSTER.md")
    if [[ "$ROW_COUNT" -ne 3 ]]; then
        echo "❌ Expected 3 roster rows (talaria disabled), found $ROW_COUNT"
        exit 1
    fi
    echo "✅ 3-agent path: $BOT_COUNT bots, $ROW_COUNT roster rows"

    echo ""
    echo "=== Crash recovery test (inner): PASS ==="
}

if [[ "${1:-}" == "--inner" ]]; then
    run_inner
    exit 0
fi

echo "=== Squad-Mind Crash Recovery Test ==="
echo "Repo: $REPO_ROOT"

# ==================================================================
# LOCAL MODE: sandboxed run on this machine (no Docker)
# ==================================================================
if [[ "${1:-}" == "--local" ]]; then
    echo "Mode: local sandbox"
    SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hermes-crash.XXXXXX")"
    trap 'rm -rf "$SANDBOX"' EXIT

    copy_repo "$REPO_ROOT" "$SANDBOX/work"

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
        bash "$SANDBOX/work/tests/crash-recovery.sh" --inner
    RC=$?
    set -e

    if [[ "$RC" -eq 0 ]]; then
        echo "=== Crash recovery test: PASS (local) ==="
    else
        echo "=== Crash recovery test: FAIL (local) ==="
    fi
    exit "$RC"
fi

# ==================================================================
# DOCKER MODE (default — used by CI)
# ==================================================================
echo "Mode: docker ($IMAGE)"
CONTAINER_NAME="hermes-crash-test-$$"

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

docker run -d --name "$CONTAINER_NAME" \
    -v "$REPO_ROOT:/workspace:ro" \
    "$IMAGE" \
    sleep 3600

docker exec "$CONTAINER_NAME" bash -c '
    apt-get update -qq
    apt-get install -y -qq curl bash git python3 python3-yaml procps ca-certificates 2>/dev/null
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
    "$CONTAINER_NAME" bash /work/tests/crash-recovery.sh --inner
RC=$?
set -e

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo ""
if [[ "$RC" -eq 0 ]]; then
    echo "=== Crash recovery test: PASS ==="
else
    echo "=== Crash recovery test: FAIL ==="
fi
exit "$RC"
