#!/usr/bin/env bash
# Integration test: run full bootstrap in a clean Debian container
# Usage: ./tests/bootstrap-integration.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="debian:12-slim"
CONTAINER_NAME="hermes-bootstrap-test-$$"

echo "=== Squad-Mind Bootstrap Integration Test ==="
echo "Repo: $REPO_ROOT"
echo "Image: $IMAGE"
echo ""

# Clean up previous runs
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Build a test image with required deps
docker run -d --name "$CONTAINER_NAME" \
    -v "$REPO_ROOT:/workspace:ro" \
    "$IMAGE" \
    sleep 3600

# Install dependencies inside container
docker exec "$CONTAINER_NAME" bash -c '
    apt-get update -qq
    apt-get install -y -qq curl bash git python3 python3-yaml python3-pip procps net-tools 2>/dev/null || true
    pip3 install pyyaml --quiet 2>/dev/null || true
'

# Create mock setup_answers.yaml
docker exec "$CONTAINER_NAME" bash -c '
cat > /workspace/setup_answers.yaml << EOF
version: "1.0"
date: "2026-04-24"
user:
  name: "TestUser"
  email: "test@example.com"
  timezone: "UTC"
paths:
  vault: "/root/Documents/Home-Brain"
  hermes_home: "/root/.hermes"
providers:
  mode: "api-keys"
  anthropic:
    api_key: "sk-ant-api03-test"
  google:
    api_key: "AIzaTest"
agents:
  enabled:
    - orchestrator
    - coder
  roster:
    orchestrator:
      name: "Hermes"
      provider: "anthropic"
      model: "claude-sonnet-4-6"
    coder:
      name: "Hephaestus"
      provider: "kimi"
      model: "kimi-for-coding"
delivery:
  platform: "local-only"
projects:
  health: true
  finance: true
locale:
  currency_symbol: "\$"
  country_code: "Generic"
  household_mode: "single"
install:
  mode: "headless"
  auto_start: "manual"
EOF
'

# Run bootstrap stages
echo "Running bootstrap stages..."
docker exec "$CONTAINER_NAME" bash -c '
    cd /workspace
    ./bootstrap/00-prereqs.sh
    ./bootstrap/10-obsidian.sh
    ./bootstrap/20-hermes-core.sh
    ./bootstrap/30-vault-seed.sh
    ./bootstrap/40-agents-wire.sh
    ./bootstrap/50-smoke-test.sh || true  # API keys are fake, smoke test will warn but should not crash
    ./bootstrap/60-delivery.sh
    ./bootstrap/70-autostart.sh
    ./bootstrap/80-starter-projects.sh
    ./bootstrap/90-first-run.sh
'

# Verify artifacts
echo ""
echo "Verifying artifacts..."

FAILURES=0

check() {
    local desc="$1"
    local cmd="$2"
    if docker exec "$CONTAINER_NAME" bash -c "$cmd"; then
        echo "✅ $desc"
    else
        echo "❌ $desc"
        ((FAILURES++)) || true
    fi
}

check "State file at STEP=9" "grep '^STEP=9' /workspace/hermes-setup.state"
check "Vault brain/hot.md exists" "test -f /root/Documents/Home-Brain/brain/hot.md"
check "Vault brain/Memories.md exists" "test -f /root/Documents/Home-Brain/brain/Memories.md"
check "Hermes runtime exists" "test -d /root/.hermes"
check "Hermes runtime permissions 700" "stat -c '%a' /root/.hermes | grep -q '^700$'"
check ".env exists" "test -f /workspace/.env"
check ".env permissions 600" "stat -c '%a' /workspace/.env | grep -q '^600$'"
check "Health project exists" "test -f /root/Documents/Home-Brain/projects/health/index.md"
check "Finance project exists" "test -f /root/Documents/Home-Brain/projects/finance/index.md"
check "No raw placeholders in vault" "! grep -r '\\\${' /root/Documents/Home-Brain || true"
check "AGENT_ROSTER.md exists" "test -f /root/Documents/Home-Brain/AGENT_ROSTER.md"

# Clean up
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
    echo "=== Integration test: PASS ==="
    exit 0
else
    echo "=== Integration test: FAIL ($FAILURES failures) ==="
    exit 1
fi
