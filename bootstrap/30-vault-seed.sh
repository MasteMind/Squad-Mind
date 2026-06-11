#!/usr/bin/env bash
# Stage 3: Seed Vault from Templates (team-brain tree)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 3

info "=== Stage 3: Vault Seeding ==="

require_answers_v2 "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

USER_NAME=$(read_yaml_key setup_answers.yaml "user.name" || echo "User")
USER_EMAIL=$(read_yaml_key setup_answers.yaml "user.email" || echo "")
TIMEZONE=$(read_yaml_key setup_answers.yaml "user.timezone" || echo "UTC")
TEAM_NAME=$(read_yaml_key setup_answers.yaml "team.name" || echo "My Team")
TEAM_DOMAIN_BLURB=$(read_yaml_key setup_answers.yaml "team.domain_blurb" \
    || echo "<!-- TODO: describe your team's domain, systems, and architecture here -->")

info "Vault path: $VAULT_PATH"

# ------------------------------------------------------------------
# Backup existing vault before overwriting
# ------------------------------------------------------------------
if [[ -d "$VAULT_PATH/brain" ]]; then
    info "Existing vault detected. Creating backup..."
    if [[ -x "scripts/backup-vault.sh" ]]; then
        ./scripts/backup-vault.sh "$VAULT_PATH" || warn "Backup script failed, proceeding anyway"
    else
        warn "backup-vault.sh not found. Skipping pre-seed backup."
    fi
fi

# ------------------------------------------------------------------
# Copy vault templates (brain/, agents/, projects/, journal/)
# ------------------------------------------------------------------
mkdir -p "$VAULT_PATH"

if [[ -d "templates/vault" ]]; then
    cp -r templates/vault/* "$VAULT_PATH/"
    info "Copied vault templates (brain/, agents/, projects/, journal/)"
else
    die "templates/vault not found"
fi

# ------------------------------------------------------------------
# Interpolate variables
# ------------------------------------------------------------------
# Skipped on purpose:
#   - files containing ROSTER_ROWS (AGENT_ROSTER.md.tmpl — rendered by stage 40)
#   - projects/_template/ (runtime-filled, uses <fill> markers)
info "Interpolating template variables..."

find "$VAULT_PATH" -type f -name "*.md" ! -path "*/projects/_template/*" | while read -r file; do
    if grep -q 'ROSTER_ROWS' "$file"; then
        continue
    fi
    render_template "$file" "$file" \
        "USER_NAME=$USER_NAME" \
        "USER_EMAIL=$USER_EMAIL" \
        "TEAM_NAME=$TEAM_NAME" \
        "TIMEZONE=$TIMEZONE" \
        "VAULT_PATH=$VAULT_PATH" \
        "HERMES_HOME=$HERMES_HOME" \
        "TEAM_DOMAIN_BLURB=$TEAM_DOMAIN_BLURB"
done

# ------------------------------------------------------------------
# Verify no raw placeholders remain
# ------------------------------------------------------------------
# (*.tmpl files — i.e. brain/AGENT_ROSTER.md.tmpl — are excluded by the
# helper; stage 40 renders the roster.)
verify_no_placeholders "$VAULT_PATH"

set_step 3
info "=== Stage 3 complete ==="
