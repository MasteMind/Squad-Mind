#!/usr/bin/env bash
# Stage 8: Seed Starter Projects (health, finance)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 8

info "=== Stage 8: Starter Projects ==="

require_file "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

USER_NAME=$(read_yaml_key setup_answers.yaml "user.name" || echo "User")
USER_EMAIL=$(read_yaml_key setup_answers.yaml "user.email" || echo "")
TIMEZONE=$(read_yaml_key setup_answers.yaml "user.timezone" || echo "UTC")
CURRENCY_SYMBOL=$(read_yaml_key setup_answers.yaml "locale.currency_symbol" || echo "$")
COUNTRY_CODE=$(read_yaml_key setup_answers.yaml "locale.country_code" || echo "Generic")
HOUSEHOLD_MODE=$(read_yaml_key setup_answers.yaml "locale.household_mode" || echo "single")

ENABLE_HEALTH=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print('true' if data.get('projects', {}).get('health', True) else 'false')
")

ENABLE_FINANCE=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print('true' if data.get('projects', {}).get('finance', True) else 'false')
")

# ------------------------------------------------------------------
# Health project
# ------------------------------------------------------------------
if [[ "$ENABLE_HEALTH" == "true" ]]; then
    if [[ -d "templates/projects/health" ]]; then
        if [[ -d "$VAULT_PATH/projects/health" ]]; then
            info "Health project already exists at $VAULT_PATH/projects/health — skipping"
        else
            mkdir -p "$VAULT_PATH/projects"
            cp -r "templates/projects/health" "$VAULT_PATH/projects/"
            info "Copied health starter project"
        fi
    else
        warn "templates/projects/health not found — skipping"
    fi
fi

# ------------------------------------------------------------------
# Finance project
# ------------------------------------------------------------------
if [[ "$ENABLE_FINANCE" == "true" ]]; then
    if [[ -d "templates/projects/finance" ]]; then
        if [[ -d "$VAULT_PATH/projects/finance" ]]; then
            info "Finance project already exists at $VAULT_PATH/projects/finance — skipping"
        else
            mkdir -p "$VAULT_PATH/projects"
            cp -r "templates/projects/finance" "$VAULT_PATH/projects/"
            info "Copied finance starter project"
        fi
    else
        warn "templates/projects/finance not found — skipping"
    fi
fi

# ------------------------------------------------------------------
# Interpolate variables in project files
# ------------------------------------------------------------------
info "Interpolating project template variables..."

find "$VAULT_PATH/projects" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
    sed_inplace \
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
if grep -r '\${' "$VAULT_PATH/projects" 2>/dev/null; then
    die "Uninterpolated variables found in project files. Check templates."
fi
info "Interpolation check: PASS"

# ------------------------------------------------------------------
# Verify expected files exist
# ------------------------------------------------------------------
if [[ "$ENABLE_HEALTH" == "true" ]]; then
    if [[ -f "$VAULT_PATH/projects/health/index.md" ]]; then
        info "Health project verification: PASS"
    else
        die "Health project index.md not found after copy"
    fi
fi

if [[ "$ENABLE_FINANCE" == "true" ]]; then
    if [[ -f "$VAULT_PATH/projects/finance/index.md" ]]; then
        info "Finance project verification: PASS"
    else
        die "Finance project index.md not found after copy"
    fi
fi

set_step 8
info "=== Stage 8 complete ==="
