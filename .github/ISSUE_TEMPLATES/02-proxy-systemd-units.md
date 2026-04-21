---
title: "Ship systemd user units for proxy auto-start and crash recovery"
labels: ["feature", "high", "proxy", "reliability"]
---

## Problem
The kit currently starts proxies via `screen` sessions (`scripts/start-proxies.sh`). If a proxy crashes (OOM, CLI error, network timeout), it stays dead until manually restarted. There is no supervision.

## Impact
- Silent failures — agents stop responding with no alert
- Proxies don't survive reboot
- Session state lost on crash

## Proposed Fix
Ship systemd user unit templates in `templates/systemd/` and wire them in `bootstrap/70-autostart.sh`:

```ini
# templates/systemd/proxy-claude.service
[Unit]
Description=Squad-Mind Claude Proxy
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

Enable during bootstrap:
```bash
systemctl --user daemon-reload
systemctl --user enable proxy-claude proxy-gemini
systemctl --user start proxy-claude proxy-gemini
```

Keep `scripts/start-proxies.sh` as a manual fallback for non-systemd systems.

## Acceptance Criteria
- [ ] `bootstrap/70-autostart.sh` generates and enables proxy systemd units
- [ ] Proxies auto-start on login and respawn within 10s of crash
- [ ] `systemctl --user status proxy-*` shows active state
- [ ] Graceful shutdown on `systemctl --user stop`
- [ ] `scripts/stop-proxies.sh` updated to handle both screen and systemd
