#!/usr/bin/env bash
# Backup the Home-Brain vault
# Usage: ./scripts/backup-vault.sh [vault_path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(dirname "$SCRIPT_DIR")"

# Determine vault path
VAULT_PATH="${1:-}"
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

if [[ ! -d "$VAULT_PATH" ]]; then
    echo "Error: Vault not found at $VAULT_PATH"
    exit 1
fi

# Determine backup directory
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
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vault_$TIMESTAMP.tar.gz"
VAULT_NAME=$(basename "$VAULT_PATH")
VAULT_PARENT=$(dirname "$VAULT_PATH")

echo "Backing up vault: $VAULT_PATH"
echo "Backup file: $BACKUP_FILE"

tar czf "$BACKUP_FILE" -C "$VAULT_PARENT" "$VAULT_NAME"

# Retain only last 10 backups
if ls "$BACKUP_DIR"/vault_*.tar.gz >/dev/null 2>&1; then
    ls -t "$BACKUP_DIR"/vault_*.tar.gz | tail -n +11 | while read -r old; do
        rm -f "$old"
    done
fi

BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/vault_*.tar.gz 2>/dev/null | wc -l)
echo "Backup complete. Total backups retained: $BACKUP_COUNT"
