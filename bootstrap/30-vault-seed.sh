#!/usr/bin/env bash
# Stage 3: Seed Vault from Templates
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 3

info "=== Stage 3: Vault Seeding ==="

require_file "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

USER_NAME=$(read_yaml_key setup_answers.yaml "user.name" || echo "User")
USER_EMAIL=$(read_yaml_key setup_answers.yaml "user.email" || echo "")
TIMEZONE=$(read_yaml_key setup_answers.yaml "user.timezone" || echo "UTC")
CURRENCY_SYMBOL=$(read_yaml_key setup_answers.yaml "locale.currency_symbol" || echo "$")
COUNTRY_CODE=$(read_yaml_key setup_answers.yaml "locale.country_code" || echo "Generic")
HOUSEHOLD_MODE=$(read_yaml_key setup_answers.yaml "locale.household_mode" || echo "single")

info "Vault path: $VAULT_PATH"

# ------------------------------------------------------------------
# Copy vault templates
# ------------------------------------------------------------------
mkdir -p "$VAULT_PATH"

if [[ -d "templates/vault" ]]; then
    cp -r templates/vault/* "$VAULT_PATH/"
    info "Copied vault templates"
fi

# ------------------------------------------------------------------
# Interpolate variables
# ------------------------------------------------------------------
info "Interpolating template variables..."

find "$VAULT_PATH" -type f -name "*.md" -o -name "*.yaml" -o -name "*.yml" | while read -r file; do
    sed -i \
        -e "s|\\\${USER_NAME}|$USER_NAME|g" \
        -e "s|\\\${USER_EMAIL}|$USER_EMAIL|g" \
        -e "s|\\\${TIMEZONE}|$TIMEZONE|g" \
        -e "s|\\\${CURRENCY_SYMBOL}|$CURRENCY_SYMBOL|g" \
        -e "s|\\\${COUNTRY_CODE}|$COUNTRY_CODE|g" \
        -e "s|\\\${HOUSEHOLD_MODE}|$HOUSEHOLD_MODE|g" \
        "$file" 2>/dev/null || true
done

# ------------------------------------------------------------------
# Verify no raw placeholders remain
# ------------------------------------------------------------------
if grep -r '\${' "$VAULT_PATH" 2>/dev/null; then
    die "Uninterpolated variables found in vault. Check template files."
fi
info "Interpolation check: PASS"

set_step 3
info "=== Stage 3 complete ==="
