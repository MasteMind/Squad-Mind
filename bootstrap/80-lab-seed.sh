#!/usr/bin/env bash
# Stage 8: Agent-Distribution-Lab Seed Verification
#
# The lab content itself is copied + interpolated by stage 30 as part of
# the vault tree. This stage verifies it landed, seeds projects/_archived/,
# and points the user at the WS bootstrap prompt. Gated by projects.lab.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 8

info "=== Stage 8: Lab Seed ==="

require_answers_v2 "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

ENABLE_LAB=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print('true' if (data.get('projects') or {}).get('lab', True) else 'false')
")

LAB_DIR="$VAULT_PATH/projects/agent-distribution-lab"

# ------------------------------------------------------------------
# projects.lab=false → remove the lab from the seeded vault
# ------------------------------------------------------------------
if [[ "$ENABLE_LAB" != "true" ]]; then
    if [[ -d "$LAB_DIR" ]]; then
        rm -rf "$LAB_DIR"
        info "projects.lab=false — removed $LAB_DIR"
    else
        info "projects.lab=false — lab not seeded, nothing to remove"
    fi
    mkdir -p "$VAULT_PATH/projects/_archived"
    set_step 8
    info "=== Stage 8 complete ==="
    exit 0
fi

# ------------------------------------------------------------------
# Verify the lab landed with its 6 files (copied by stage 30)
# ------------------------------------------------------------------
LAB_FILES=(
    "README.md"
    "profiles.md"
    "ranker.md"
    "poc-validation.md"
    "results.md"
    "prompts/new-ws-bootstrap.md"
)

MISSING=0
for f in "${LAB_FILES[@]}"; do
    if [[ ! -f "$LAB_DIR/$f" ]]; then
        error "Missing lab file: $LAB_DIR/$f"
        MISSING=1
    fi
done

if [[ "$MISSING" -ne 0 ]]; then
    die "agent-distribution-lab is incomplete. Re-run bootstrap/30-vault-seed.sh."
fi
info "Lab verification: PASS (${#LAB_FILES[@]} files present)"

# ------------------------------------------------------------------
# Seed projects/_archived/
# ------------------------------------------------------------------
mkdir -p "$VAULT_PATH/projects/_archived"
info "projects/_archived/ ready"

# ------------------------------------------------------------------
# WS bootstrap pointer
# ------------------------------------------------------------------
cat << EOF

Agent-distribution-lab is seeded at:
  $LAB_DIR

To start a new working session (WS), have your orchestrator read:
  $LAB_DIR/prompts/new-ws-bootstrap.md

EOF

set_step 8
info "=== Stage 8 complete ==="
