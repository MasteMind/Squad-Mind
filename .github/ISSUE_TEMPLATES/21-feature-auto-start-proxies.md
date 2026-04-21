---
title: "[FEATURE] Auto-start proxies on boot via systemd"
labels: ["feature", "proxy", "reliability"]
---

## Description
Currently proxies must be started manually with `scripts/start-proxies.sh`. After a system reboot, all agents are down until someone remembers to start them.

## Proposed Solution
`bootstrap/70-autostart.sh` should create systemd user units for each proxy:

```ini
# ~/.config/systemd/user/proxy-claude.service
[Unit]
Description=Claude llm-cli-proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.npm-global/bin/llm-cli-proxy --provider claude --port 3456
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

Enable all:
```bash
systemctl --user daemon-reload
systemctl --user enable proxy-claude proxy-clio proxy-athena proxy-asclepius
systemctl --user start proxy-claude proxy-clio proxy-athena proxy-asclepius
```

## Acceptance Criteria
- [ ] `bootstrap/70-autostart.sh` creates proxy systemd units
- [ ] Proxies start automatically after login/reboot
- [ ] `systemctl --user status proxy-*` shows active
- [ ] Failed proxies auto-restart within 10 seconds
