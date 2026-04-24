#!/usr/bin/env bash
# Stage 9: First Run — Hermes Reads Brain
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 9

info "=== Stage 9: First-Run Simulation ==="

require_file "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

# ------------------------------------------------------------------
# Validate brain files exist
# ------------------------------------------------------------------
if [[ ! -f "$VAULT_PATH/brain/hot.md" ]]; then
    die "brain/hot.md not found in vault"
fi

if [[ ! -f "$VAULT_PATH/brain/Memories.md" ]]; then
    die "brain/Memories.md not found in vault"
fi

info "Brain files present"

# ------------------------------------------------------------------
# Run mock orchestrator
# ------------------------------------------------------------------
MOCK_ORCHESTRATOR="$(dirname "$0")/lib/mock-orchestrator.py"

if [[ -f "$MOCK_ORCHESTRATOR" ]]; then
    info "Running mock orchestrator..."
    if python3 "$MOCK_ORCHESTRATOR" "$VAULT_PATH"; then
        info "Mock orchestrator: PASS"
    else
        die "Mock orchestrator failed. Vault may be corrupted or frontmatter invalid."
    fi
else
    warn "mock-orchestrator.py not found — skipping orchestrator validation"
fi

# ------------------------------------------------------------------
# Validate AGENT_ROSTER.md exists
# ------------------------------------------------------------------
if [[ -f "$VAULT_PATH/AGENT_ROSTER.md" ]]; then
    info "AGENT_ROSTER.md present"
else
    warn "AGENT_ROSTER.md not found"
fi

# ------------------------------------------------------------------
# Validate .env exists and is readable
# ------------------------------------------------------------------
if [[ -f ".env" ]]; then
    info ".env present"
else
    warn ".env not found in setup directory"
fi

# ------------------------------------------------------------------
# Validate delivery profiles (if configured)
# ------------------------------------------------------------------
PLATFORM=$(read_yaml_key setup_answers.yaml "delivery.platform" || echo "local-only")
if [[ "$PLATFORM" == "telegram" && -f "$HERMES_HOME/profiles/telegram.yaml" ]]; then
    info "Telegram profile present"
fi
if [[ "$PLATFORM" == "slack" && -f "$HERMES_HOME/profiles/slack.yaml" ]]; then
    info "Slack profile present"
fi

# ------------------------------------------------------------------
# System summary
# ------------------------------------------------------------------
ENABLED_AGENTS=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print(', '.join(data.get('agents', {}).get('enabled', [])))
" 2>/dev/null || echo "unknown")

cat << EOF

╔══════════════════════════════════════════════════════════════╗
║                SQUAD-MIND SYSTEM READY                       ║
╠══════════════════════════════════════════════════════════════╣
║ Vault:        $VAULT_PATH
║ Runtime:      $HERMES_HOME
║ Agents:       $ENABLED_AGENTS
║ Delivery:     $PLATFORM
╚══════════════════════════════════════════════════════════════╝

Next steps:
  1. Open your vault: cd "$VAULT_PATH"
  2. Edit brain/hot.md to set today's priorities
  3. Start proxies (if cli-proxy mode): ./scripts/start-proxies.sh
  4. Run health check: ./scripts/health-check.sh (when available)

EOF

set_step 9
info "=== Stage 9 complete ==="
