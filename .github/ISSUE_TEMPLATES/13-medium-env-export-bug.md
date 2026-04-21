---
title: "[MEDIUM] 50-smoke-test.sh uses unsafe env export pattern"
labels: ["bug", "medium", "bootstrap"]
---

## Description
```bash
export $(grep -v '^#' .env | xargs) 2>/dev/null || true
```
This pattern:
- Fails on values with spaces
- Is vulnerable to command injection if `.env` contains malicious values
- Silently ignores errors with `|| true`

## Fix
Replace with:
```bash
set -a
source .env
set +a
```

Or use a Python one-liner for safe parsing:
```bash
python3 -c "
import os, re
with open('.env') as f:
    for line in f:
        if line.strip() and not line.startswith('#'):
            k, v = line.strip().split('=', 1)
            os.environ[k] = v
"
```

## Acceptance Criteria
- [ ] `50-smoke-test.sh` doesn't use `export $(grep...xargs)`
- [ ] `.env` values with spaces parse correctly
- [ ] Shellcheck passes on the script
