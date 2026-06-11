#!/usr/bin/env bash
# Stage 9: First Run — Validate the Wired Squad
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 9

info "=== Stage 9: First-Run Validation ==="

require_answers_v2 "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

TALARIA_ENABLED=$(read_yaml_key setup_answers.yaml "agents.talaria_enabled" || echo "")
if [[ -z "$TALARIA_ENABLED" ]]; then
    if read_yaml_key setup_answers.yaml "ollama.base_url" >/dev/null; then
        TALARIA_ENABLED="true"
    else
        TALARIA_ENABLED="false"
    fi
fi
case "$TALARIA_ENABLED" in
    True|true|yes|1) TALARIA_ENABLED="true" ;;
    *) TALARIA_ENABLED="false" ;;
esac

ENABLE_LAB=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print('true' if (data.get('projects') or {}).get('lab', True) else 'false')
")

# ------------------------------------------------------------------
# Validate brain files exist
# ------------------------------------------------------------------
for brain_file in hot.md Memories.md Skills.md; do
    if [[ ! -f "$VAULT_PATH/brain/$brain_file" ]]; then
        die "brain/$brain_file not found in vault"
    fi
done
info "Brain files present"

# ------------------------------------------------------------------
# Validate bot YAMLs exist and parse
# ------------------------------------------------------------------
EXPECTED_AGENTS="hermes hephaestus clio"
EXPECTED_COUNT=3
if [[ "$TALARIA_ENABLED" == "true" ]]; then
    EXPECTED_AGENTS="$EXPECTED_AGENTS talaria"
    EXPECTED_COUNT=4
fi

for agent_id in $EXPECTED_AGENTS; do
    BOT_YAML="$HERMES_HOME/bots/${agent_id}.yaml"
    if [[ ! -f "$BOT_YAML" ]]; then
        die "Bot YAML missing: $BOT_YAML (run stage 40)"
    fi
    if ! python3 -c "import yaml; yaml.safe_load(open('$BOT_YAML'))" 2>/dev/null; then
        die "Bot YAML does not parse: $BOT_YAML"
    fi
done
info "Bot YAMLs: $EXPECTED_COUNT present and parse"

# ------------------------------------------------------------------
# Validate AGENT_ROSTER.md row count
# ------------------------------------------------------------------
ROSTER="$VAULT_PATH/brain/AGENT_ROSTER.md"
if [[ ! -f "$ROSTER" ]]; then
    die "brain/AGENT_ROSTER.md not found (run stage 40)"
fi
ROW_COUNT=$(grep -c '| active |' "$ROSTER" || true)
if [[ "$ROW_COUNT" -ne "$EXPECTED_COUNT" ]]; then
    die "AGENT_ROSTER.md has $ROW_COUNT agent rows, expected $EXPECTED_COUNT"
fi
info "AGENT_ROSTER.md: $ROW_COUNT agent rows"

# ------------------------------------------------------------------
# Validate lab README (when projects.lab enabled)
# ------------------------------------------------------------------
if [[ "$ENABLE_LAB" == "true" ]]; then
    if [[ ! -f "$VAULT_PATH/projects/agent-distribution-lab/README.md" ]]; then
        die "agent-distribution-lab README.md not found (run stage 80)"
    fi
    info "Lab README present"
fi

# ------------------------------------------------------------------
# No unrendered placeholders anywhere
# ------------------------------------------------------------------
verify_no_placeholders "$VAULT_PATH"
verify_no_placeholders "$HERMES_HOME/bots"

# ------------------------------------------------------------------
# Run mock orchestrator (brain validation)
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
cat << EOF

╔══════════════════════════════════════════════════════════════╗
║                SQUAD-MIND SYSTEM READY                       ║
╠══════════════════════════════════════════════════════════════╣
║ Vault:        $VAULT_PATH
║ Runtime:      $HERMES_HOME
║ Agents:       $EXPECTED_AGENTS
║ Delivery:     $PLATFORM
╚══════════════════════════════════════════════════════════════╝

Next steps:
  1. Open your vault: cd "$VAULT_PATH"
  2. Edit brain/hot.md to set today's priorities
  3. Start proxies (if cli-proxy mode): $HERMES_HOME/scripts/start-proxies.sh
  4. Roster + per-agent details: $VAULT_PATH/brain/AGENT_ROSTER.md

EOF

set_step 9
info "=== Stage 9 complete ==="
