---
title: "Ship system health check script"
labels: ["feature", "medium", "monitoring"]
---

## Problem
No single command verifies the entire Squad-Mind stack is working. Users must manually check proxies, Hermes, disk space, etc.

## Proposed Fix
`scripts/health-check.sh`:

```bash
#!/bin/bash
echo "=== Squad-Mind Health Check ==="

# Proxies
for port in 3456 3457 3458 3459; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/health" 2>/dev/null || echo "down")
    echo "  Proxy port $port: $status"
done

# Disk
df -h "$HOME" | tail -1 | awk '{print "  Disk free: "$4}'

# Vault
if [ -f "${VAULT_PATH:-$HOME/Documents/Home-Brain}/brain/hot.md" ]; then
    echo "  Vault: OK"
else
    echo "  Vault: MISSING"
fi

# Hermes
if [ -f "${HERMES_HOME:-$HOME/.hermes}/config.yaml" ]; then
    echo "  Hermes config: OK"
else
    echo "  Hermes config: MISSING"
fi
```

## Acceptance Criteria
- [ ] `scripts/health-check.sh` runs without errors
- [ ] Exit code 0 if all critical checks pass, 1 otherwise
- [ ] Optional JSON output: `--json`
- [ ] Documented in README
