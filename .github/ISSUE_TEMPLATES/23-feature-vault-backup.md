---
title: "[FEATURE] Built-in vault backup before destructive operations"
labels: ["feature", "reliability", "vault"]
---

## Description
Bootstrap operations (re-seeding, re-interviewing) can overwrite user data. There's no automatic backup before these operations.

## Proposed Solution
Add a `backup-vault.sh` script:

```bash
#!/bin/bash
VAULT="$HOME/Documents/Home-Brain"
BACKUP_DIR="$HOME/.hermes/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

tar czf "$BACKUP_DIR/vault_$TIMESTAMP.tar.gz" -C "$(dirname "$VAULT")" "$(basename "$VAULT")"
# Keep only last 10 backups
ls -t "$BACKUP_DIR"/vault_*.tar.gz | tail -n +11 | xargs -r rm
```

Run automatically before:
- `30-vault-seed.sh` (re-seeding)
- `scripts/uninstall.sh --purge`
- Any operation that modifies `brain/` or `projects/`

## Acceptance Criteria
- [ ] `scripts/backup-vault.sh` creates timestamped tar.gz
- [ ] Backups run automatically before destructive ops
- [ ] Only last 10 backups retained
- [ ] Restore script: `scripts/restore-vault.sh 20260421_120000`
