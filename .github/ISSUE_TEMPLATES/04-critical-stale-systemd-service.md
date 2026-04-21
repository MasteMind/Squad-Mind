---
title: "[CRITICAL] Stale systemd service references old proxy architecture"
labels: ["reliability", "critical", "proxy"]
---

## Description
`claude-max-api.service` (or similar legacy systemd unit) still exists and references the old `claude-max-api-proxy` that was replaced by `llm-cli-proxy`. This can cause:
- Port conflicts on startup
- Confusion about which proxy is "official"
- Failed auto-start on boot

## Evidence
Old proxy patches were reverted but systemd units may remain.

## Fix
1. List all hermes-related systemd units:
   ```bash
   systemctl --user list-unit-files | grep -E 'hermes|proxy|claude'
   ```
2. Remove obsolete units:
   ```bash
   rm -f ~/.config/systemd/user/claude-max-api.service
   systemctl --user daemon-reload
   ```
3. Create new units for `llm-cli-proxy` (see issue #02)

## Acceptance Criteria
- [ ] No systemd units reference `claude-max-api-proxy`
- [ ] All proxy services use `llm-cli-proxy`
- [ ] `systemctl --user list-unit-files | grep proxy` shows only current proxies
