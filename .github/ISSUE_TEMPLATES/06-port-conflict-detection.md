---
title: "start-proxies.sh should detect and report port conflicts"
labels: ["bug", "medium", "bootstrap"]
---

## Problem
`scripts/start-proxies.sh` starts proxies on fixed ports without checking if they're already in use. This causes confusing failures when another process (or a stale proxy) holds the port.

## Proposed Fix
Add pre-flight port check:
```bash
for port in 3456 3457 3458 3459; do
    if ss -tlnp | grep -q ":$port "; then
        echo "ERROR: Port $port already in use."
        ss -tlnp | grep ":$port "
        exit 1
    fi
done
```

Optional: auto-increment to next free port and update `.env` accordingly.

## Acceptance Criteria
- [ ] Script exits with clear error if port is occupied
- [ ] Shows which process owns the port
- [ ] Documented in troubleshooting section
