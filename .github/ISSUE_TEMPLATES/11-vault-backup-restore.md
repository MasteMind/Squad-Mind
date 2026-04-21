---
title: "Ship vault backup and restore scripts"
labels: ["feature", "medium", "reliability"]
---

## Problem
Destructive operations (re-seeding, re-interviewing, uninstall --purge) can overwrite user data. The kit provides no safety net.

## Proposed Fix
Add `scripts/backup-vault.sh` and `scripts/restore-vault.sh`:

```bash
# backup-vault.sh
VAULT="${VAULT_PATH:-$HOME/Documents/Home-Brain}"
BACKUP_DIR="${HERMES_HOME:-$HOME/.hermes}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
tar czf "$BACKUP_DIR/vault_$TIMESTAMP.tar.gz" -C "$(dirname "$VAULT")" "$(basename "$VAULT")"
ls -t "$BACKUP_DIR"/vault_*.tar.gz | tail -n +11 | xargs -r rm
```

Auto-run before:
- `30-vault-seed.sh` (if vault already exists)
- `uninstall.sh --purge`

## Acceptance Criteria
- [ ] `scripts/backup-vault.sh` creates timestamped tar.gz
- [ ] Backups auto-run before destructive operations
- [ ] Only last 10 backups retained
- [ ] `scripts/restore-vault.sh YYYYMMDD_HHMMSS` restores from backup
- [ ] Documented in README troubleshooting
