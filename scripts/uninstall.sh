#!/usr/bin/env bash
# Uninstall Hermes — removes runtime, optionally purges vault
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_SETUP_DIR="$(dirname "$SCRIPT_DIR")"

PURGE=false
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
VAULT_PATH=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --purge)
            PURGE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--purge]"
            echo "  --purge    Also delete the vault (irreversible)"
            exit 0
            ;;
    esac
done

# Try to read vault path from setup_answers.yaml
if [[ -f "$HERMES_SETUP_DIR/setup_answers.yaml" ]]; then
    VAULT_PATH=$(python3 -c "
import yaml
try:
    with open('$HERMES_SETUP_DIR/setup_answers.yaml') as f:
        data = yaml.safe_load(f)
    print(data.get('paths', {}).get('vault', ''))
except:
    pass
" 2>/dev/null)
fi

echo "=== Hermes Uninstall ==="
echo ""
echo "This will remove:"
echo "  - Hermes runtime: $HERMES_HOME"
if [[ "$PURGE" == true ]]; then
    if [[ -n "$VAULT_PATH" ]]; then
        echo "  - Vault: $VAULT_PATH"
    else
        echo "  - Vault: (could not detect from setup_answers.yaml)"
    fi
fi
echo ""
read -p "Are you sure? Type 'yes' to proceed: " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

# Remove runtime
if [[ -d "$HERMES_HOME" ]]; then
    rm -rf "$HERMES_HOME"
    echo "Removed $HERMES_HOME"
fi

# Remove systemd services
if command -v systemctl &>/dev/null; then
    systemctl --user stop hermes-orchestrator 2>/dev/null || true
    systemctl --user disable hermes-orchestrator 2>/dev/null || true
    find "$HOME/.config/systemd/user" -maxdepth 1 -name 'hermes-*.service' -delete
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Removed systemd user services"
fi

# Remove .env
if [[ -f "$HERMES_SETUP_DIR/.env" ]]; then
    rm -f "$HERMES_SETUP_DIR/.env"
    echo "Removed .env"
fi

# Purge vault
if [[ "$PURGE" == true ]]; then
    if [[ -n "$VAULT_PATH" && -d "$VAULT_PATH" ]]; then
        echo "Creating backup before purge..."
        if [[ -x "$SCRIPT_DIR/backup-vault.sh" ]]; then
            "$SCRIPT_DIR/backup-vault.sh" "$VAULT_PATH" || echo "Warning: Backup failed, proceeding with purge"
        fi
        rm -rf "$VAULT_PATH"
        echo "Removed vault at $VAULT_PATH"
    else
        echo "Warning: Could not determine vault path. Manual removal may be needed."
    fi
fi

# Remove state file
rm -f "$HERMES_SETUP_DIR/hermes-setup.state"

echo ""
echo "Uninstall complete."
if [[ "$PURGE" != true && -n "$VAULT_PATH" ]]; then
    echo "Vault preserved at: $VAULT_PATH"
    echo "To remove it too, run: $0 --purge"
fi
