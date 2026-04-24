#!/usr/bin/env bash
# Restore the Home-Brain vault from a backup
# Usage: ./scripts/restore-vault.sh YYYYMMDD_HHMMSS [vault_path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(dirname "$SCRIPT_DIR")"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <timestamp> [vault_path]"
    echo "  timestamp: YYYYMMDD_HHMMSS from backup filename"
    echo "  vault_path: path to restore to (default: from setup_answers.yaml or ~/Documents/Home-Brain)"
    echo ""
    echo "Available backups:"
    HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
    ls -1 "$HERMES_HOME"/backups/vault_*.tar.gz 2>/dev/null | sed 's|.*/vault_|  - |; s|\.tar\.gz||' || echo "  (none)"
    exit 1
fi

TIMESTAMP="$1"

# Determine vault path
VAULT_PATH="${2:-}"
if [[ -z "$VAULT_PATH" ]]; then
    if [[ -f "$SETUP_DIR/setup_answers.yaml" ]]; then
        VAULT_PATH=$(python3 -c "
import yaml
with open('$SETUP_DIR/setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print(data.get('paths', {}).get('vault', ''))
" 2>/dev/null)
    fi
fi
if [[ -z "$VAULT_PATH" ]]; then
    VAULT_PATH="$HOME/Documents/Home-Brain"
fi
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
if [[ -f "$SETUP_DIR/setup_answers.yaml" ]]; then
    HERMES_HOME=$(python3 -c "
import yaml
with open('$SETUP_DIR/setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print(data.get('paths', {}).get('hermes_home', '$HERMES_HOME'))
" 2>/dev/null)
    HERMES_HOME="${HERMES_HOME/#\~/$HOME}"
fi
BACKUP_DIR="$HERMES_HOME/backups"
BACKUP_FILE="$BACKUP_DIR/vault_$TIMESTAMP.tar.gz"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Error: Backup not found: $BACKUP_FILE"
    exit 1
fi

VAULT_NAME=$(basename "$VAULT_PATH")
VAULT_PARENT=$(dirname "$VAULT_PATH")

echo "=== Vault Restore ==="
echo "Backup: $BACKUP_FILE"
echo "Target: $VAULT_PATH"

if [[ -d "$VAULT_PATH" ]]; then
    echo "WARNING: Vault already exists at $VAULT_PATH"
    read -p "Overwrite? Type 'yes' to proceed: " confirm </dev/tty
    if [[ "$confirm" != "yes" ]]; then
        echo "Aborted."
        exit 1
    fi
    rm -rf "$VAULT_PATH"
fi

mkdir -p "$VAULT_PARENT"
tar xzf "$BACKUP_FILE" -C "$VAULT_PARENT"

echo "Restore complete: $VAULT_PATH"
