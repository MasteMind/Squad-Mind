---
title: "[FEATURE] Agent health dashboard script"
labels: ["feature", "monitoring"]
---

## Description
No single command to check if the entire system is healthy. Users must manually check proxies, Hermes, disk space, etc.

## Proposed Solution
`scripts/health-check.sh`:

```bash
#!/bin/bash
echo "=== Squad-Mind Health Check ==="
echo ""

# Proxies
for port in 3456 3457 3458 3459; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/health" 2>/dev/null || echo "down")
    echo "Proxy port $port: $status"
done

# Hermes
test -f ~/Documents/Home-Brain/gateway.pid && \
    kill -0 "$(cat ~/Documents/Home-Brain/gateway.pid)" 2>/dev/null && \
    echo "Hermes gateway: RUNNING" || echo "Hermes gateway: DOWN"

# Disk space
df -h "$HOME" | tail -1 | awk '{print "Disk free: "$4}'

# Vault integrity
test -f ~/Documents/Home-Brain/brain/hot.md && \
    echo "Vault: OK" || echo "Vault: MISSING"
```

## Acceptance Criteria
- [ ] `scripts/health-check.sh` runs without errors
- [ ] Shows proxy status, Hermes status, disk, vault integrity
- [ ] Exit code 0 if healthy, 1 if any critical check fails
- [ ] Optional: JSON output for monitoring integration
