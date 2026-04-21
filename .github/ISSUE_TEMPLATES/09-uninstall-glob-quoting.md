---
title: "uninstall.sh has unquoted glob pattern"
labels: ["bug", "low", "bootstrap"]
---

## Problem
```bash
rm -f $HOME/.config/systemd/user/hermes-*.service
```
The glob is unquoted. If no files match, the literal string `hermes-*.service` is passed to `rm`, which fails harmlessly but produces noise.

## Proposed Fix
```bash
rm -f "$HOME"/.config/systemd/user/hermes-*.service
```

## Acceptance Criteria
- [ ] All globs in `uninstall.sh` quoted correctly
- [ ] Shellcheck passes
