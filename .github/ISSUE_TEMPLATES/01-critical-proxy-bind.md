---
title: "[CRITICAL] Proxies bind to 0.0.0.0 instead of 127.0.0.1"
labels: ["security", "critical", "proxy"]
---

## Description
`llm-cli-proxy` listens on all interfaces (`0.0.0.0`) by default. On machines with public IPs or on shared networks, anyone who can reach the machine can send requests to the proxy without authentication.

## Risk
- Unauthorized API usage through your Claude Max / Gemini Advanced subscriptions
- Potential token exfiltration if proxy is reachable from network
- No access control — anyone on LAN can hit `http://<your-ip>:3456/v1/chat/completions`

## Evidence
```
$ ss -tlnp | grep 3456
LISTEN 0 511 *:3456 *:* users:(("node",pid=...,fd=21))
```
The `*` means all interfaces.

## Fix
Patch `llm-cli-proxy` to bind to `127.0.0.1` only, or run behind a local firewall rule:

```bash
# Quick firewall fix (iptables)
iptables -A INPUT -p tcp --dport 3456 -j DROP
iptables -A INPUT -p tcp -s 127.0.0.1 --dport 3456 -j ACCEPT
```

Or modify the proxy source to pass `'127.0.0.1'` as the host to `app.listen()`.

## Acceptance Criteria
- [ ] `ss -tlnp | grep 3456` shows `127.0.0.1:3456` not `*:3456`
- [ ] Same for ports 3457, 3458, 3459
