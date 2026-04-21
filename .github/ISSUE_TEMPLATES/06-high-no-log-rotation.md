---
title: "[HIGH] Proxy logs grow unbounded with no rotation"
labels: ["reliability", "high", "proxy"]
---

## Description
Proxy logs (`/tmp/proxy-*.log`, screen session output) append indefinitely. On a busy system, this can consume gigabytes of disk space and eventually cause the proxy to fail when `/tmp` fills up.

## Evidence
```bash
$ ls -lah /tmp/proxy-*.log
# These files grow without limit
```

## Fix
Add `logrotate` configuration or use `systemd-journald` (if using systemd):

```bash
# /etc/logrotate.d/llm-cli-proxy
/tmp/proxy-*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 user user
}
```

Or redirect proxy output through `split` or `rotatelogs`:
```bash
llm-cli-proxy ... 2>&1 | rotatelogs /tmp/proxy-claude.log 10M
```

## Acceptance Criteria
- [ ] Logs rotate daily or at 10MB
- [ ] Old logs compressed and auto-deleted after 7 days
- [ ] No single log file exceeds 100MB
