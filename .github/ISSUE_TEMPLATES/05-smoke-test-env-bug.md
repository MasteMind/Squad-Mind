---
title: "50-smoke-test.sh uses unsafe env export pattern"
labels: ["bug", "medium", "bootstrap"]
---

## Problem
```bash
export $(grep -v '^#' .env | xargs) 2>/dev/null || true
```
This fails on values with spaces and is vulnerable to command injection if `.env` contains malicious input.

## Proposed Fix
Replace with safe sourcing:
```bash
set -a
source .env
set +a
```

Or validate with a Python helper for maximum compatibility.

## Acceptance Criteria
- [ ] `50-smoke-test.sh` doesn't use `export $(grep...xargs)`
- [ ] `.env` values with spaces parse correctly
- [ ] Shellcheck passes on the script
