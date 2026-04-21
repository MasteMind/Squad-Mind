---
title: "[LOW] uninstall.sh has unquoted glob pattern"
labels: ["bug", "low", "bootstrap"]
---

## Description
```bash
rm -f $HOME/.config/systemd/user/hermes-*.service
```
The glob is unquoted. If no files match, the literal string `hermes-*.service` is passed to `rm`, which fails harmlessly but is noisy.

## Fix
```bash
rm -f "$HOME"/.config/systemd/user/hermes-*.service
```

## Acceptance Criteria
- [ ] All glob patterns in `uninstall.sh` are quoted properly
- [ ] Shellcheck passes on `uninstall.sh`
