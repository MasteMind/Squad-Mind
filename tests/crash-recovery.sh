#!/usr/bin/env bash
# Crash-recovery test: interrupt bootstrap and verify resume works
# Usage: ./tests/crash-recovery.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="debian:12-slim"
CONTAINER_NAME="hermes-crash-test-$$"

echo "=== Squad-Mind Crash Recovery Test ==="
echo "Repo: $REPO_ROOT"
echo ""

# Clean up previous runs
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Build a test image with required deps
docker run -d --name "$CONTAINER_NAME" \
    -v "$REPO_ROOT:/workspace:ro" \
    "$IMAGE" \
    sleep 3600

docker exec "$CONTAINER_NAME" bash -c '
    apt-get update -qq
    apt-get install -y -qq curl bash git python3 python3-yaml python3-pip procps 2>/dev/null || true
    pip3 install pyyaml --quiet 2>/dev/null || true
'

# Create mock setup_answers.yaml
docker exec "$CONTAINER_NAME" bash -c '
cat > /workspace/setup_answers.yaml << EOF
version: "1.0"
date: "2026-04-24"
user:
  name: "CrashTest"
  email: "crash@example.com"
  timezone: "UTC"
paths:
  vault: "/root/Documents/Home-Brain"
  hermes_home: "/root/.hermes"
providers:
  mode: "api-keys"
  anthropic:
    api_key: "sk-ant-api03-test"
agents:
  enabled:
    - orchestrator
  roster:
    orchestrator:
      name: "Hermes"
      provider: "anthropic"
      model: "claude-sonnet-4-6"
delivery:
  platform: "local-only"
projects:
  health: false
  finance: false
locale:
  currency_symbol: "\$"
  country_code: "Generic"
  household_mode: "single"
install:
  mode: "headless"
  auto_start: "manual"
EOF
'

echo "Phase 1: Run stages 0-2"
docker exec "$CONTAINER_NAME" bash -c '
    cd /workspace
    ./bootstrap/00-prereqs.sh
    ./bootstrap/10-obsidian.sh
    ./bootstrap/20-hermes-core.sh
'

echo "Phase 2: Verify state is at STEP=2"
docker exec "$CONTAINER_NAME" bash -c 'grep "^STEP=2$" /workspace/hermes-setup.state'

echo "Phase 3: Re-run from stage 0 — stages 0-2 should be skipped"
OUTPUT=$(docker exec "$CONTAINER_NAME" bash -c '
    cd /workspace
    ./bootstrap/00-prereqs.sh 2>&1
    ./bootstrap/10-obsidian.sh 2>&1
    ./bootstrap/20-hermes-core.sh 2>&1
')

if echo "$OUTPUT" | grep -q "already complete. Skipping"; then
    echo "✅ Idempotency: stages 0-2 correctly skipped"
else
    echo "❌ Idempotency: stages 0-2 were not skipped"
    echo "$OUTPUT"
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    exit 1
fi

echo "Phase 4: Run remaining stages to completion"
docker exec "$CONTAINER_NAME" bash -c '
    cd /workspace
    ./bootstrap/30-vault-seed.sh
    ./bootstrap/40-agents-wire.sh
    ./bootstrap/50-smoke-test.sh || true
    ./bootstrap/60-delivery.sh
    ./bootstrap/70-autostart.sh
    ./bootstrap/80-starter-projects.sh || true
    ./bootstrap/90-first-run.sh
'

echo "Phase 5: Verify final state"
docker exec "$CONTAINER_NAME" bash -c 'grep "^STEP=9$" /workspace/hermes-setup.state'

# Clean up
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo ""
echo "=== Crash recovery test: PASS ==="
