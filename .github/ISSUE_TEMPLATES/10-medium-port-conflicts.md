---
title: "[MEDIUM] start-proxies.sh has no port conflict detection"
labels: ["bug", "medium", "bootstrap"]
---

## Description
`scripts/start-proxies.sh` blindly starts proxies on fixed ports. If another process is already listening (e.g., leftover proxy, another service), it fails silently or causes confusing errors.

## Fix
Add port availability check before starting:

```bash
# In start-proxies.sh
for port in 3456 3457 3458 3459; do
    if ss -tlnp | grep -q ":$port "; then
        echo "ERROR: Port $port is already in use. Kill existing process or change port."
        exit 1
    fi
done
```

Or auto-increment to next available port:
```bash
find_free_port() {
    local start=$1
    while ss -tlnp | grep -q ":$start "; do
        ((start++))
    done
    echo $start
}
```

## Acceptance Criteria
- [ ] `start-proxies.sh` checks port availability before binding
- [ ] Clear error message if port is in use
- [ ] Optional: auto-increment to find free port
