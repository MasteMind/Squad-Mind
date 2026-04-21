---
title: "[MEDIUM] gateway.pid may reference stale process"
labels: ["bug", "medium", "hermes"]
---

## Description
`Home-Brain/gateway.pid` contains a PID. If Hermes crashed or was killed without cleanup, this PID may belong to a completely different process now.

## Fix
Add a startup check:
```bash
# In Hermes startup script
if [ -f gateway.pid ]; then
    PID=$(cat gateway.pid)
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo "Removing stale gateway.pid (PID $PID not running)"
        rm -f gateway.pid
    fi
fi
```

## Acceptance Criteria
- [ ] Stale PID files are detected and removed on startup
- [ ] `gateway.pid` always points to a running Hermes process
