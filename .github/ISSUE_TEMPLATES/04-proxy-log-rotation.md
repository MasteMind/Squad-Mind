---
title: "Ship logrotate config for proxy logs"
labels: ["feature", "medium", "proxy", "reliability"]
---

## Problem
Proxy output (screen logs, stdout) grows indefinitely. On busy systems this fills `/tmp` or `~/.local/share`, eventually causing proxy failure.

## Proposed Fix
Ship a logrotate config and integrate it into bootstrap:

```bash
# bootstrap/60-logging.sh (new stage)
sudo tee /etc/logrotate.d/squad-mind << 'EOF'
/var/log/squad-mind/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $USER $USER
}
EOF
```

Also update `start-proxies.sh` to log to `/var/log/squad-mind/` or `~/.local/share/squad-mind/logs/` instead of `/tmp`.

## Acceptance Criteria
- [ ] Logs rotate daily or at 10MB
- [ ] Old logs compressed and pruned after 7 days
- [ ] No single log file exceeds 100MB
- [ ] Systemd mode uses journald (no extra log files needed)
