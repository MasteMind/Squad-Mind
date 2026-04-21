---
title: "Proxy defaults bind to 0.0.0.0 — kit should enforce 127.0.0.1"
labels: ["security", "high", "proxy"]
---

## Problem
`llm-cli-proxy` listens on all interfaces (`0.0.0.0`) by default. On machines with public IPs or on shared networks, the proxy is reachable from outside localhost with no authentication.

## Impact
- Unauthorized API usage through user's CLI subscriptions
- No access control on LAN
- Violates principle of least privilege

## Proposed Fix

**Option A — Patch llm-cli-proxy:**
Contribute upstream or fork to pass `'127.0.0.1'` to `app.listen()`.

**Option B — Wrapper script:**
`scripts/start-proxies.sh` should check binding after start and warn/fail if not localhost:
```bash
if ss -tlnp | grep ":$port " | grep -q "\*:"; then
    echo "WARNING: Proxy bound to 0.0.0.0. Restricting to 127.0.0.1..."
    # Restart with wrapper or firewall rule
fi
```

**Option C — Firewall helper:**
Add `scripts/lockdown-proxies.sh` that adds local iptables/nftables rules.

## Acceptance Criteria
- [ ] Default install results in proxies on `127.0.0.1` only
- [ ] Smoke test verifies binding is localhost
- [ ] Documentation warns about public binding
- [ ] Non-localhost binding requires explicit opt-in
