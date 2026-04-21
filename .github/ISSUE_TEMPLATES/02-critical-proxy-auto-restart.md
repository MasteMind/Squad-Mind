---
title: "[CRITICAL] No auto-restart when llm-cli-proxy crashes"
labels: ["reliability", "critical", "proxy"]
---

## Description
Proxies run in `screen` sessions with no supervision. If the proxy process crashes (OOM, Claude CLI error, network timeout), it stays dead until manually restarted. Hermes will fail all requests until someone runs `screen -r` or restarts the proxy.

## Risk
- Silent failure — agents stop responding with no alert
- Downtime until manual intervention
- Session state lost on crash (resume IDs gone)

## Evidence
```bash
$ screen -ls
# If proxy-claude dies, it's just gone from this list
```

## Fix
Convert from `screen` to `systemd` user services with `Restart=always`:

```ini
# ~/.config/systemd/user/proxy-claude.service
[Unit]
Description=Claude llm-cli-proxy
After=network.target

[Service]
Type=simple
ExecStart=%h/.npm-global/bin/llm-cli-proxy --provider claude --port 3456
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Enable: `systemctl --user enable proxy-claude.service`

## Acceptance Criteria
- [ ] All 4 proxies have systemd units with `Restart=always`
- [ ] Killing a proxy process causes it to respawn within 5 seconds
- [ ] `systemctl --user status proxy-*` shows active state
- [ ] Old screen sessions cleaned up
