---
title: "[LOW] install.sh fails with curl | bash due to missing TTY"
labels: ["bug", "low", "bootstrap"]
---

## Description
`scripts/install.sh` uses `read` for interactive prompts. When piped via `curl | bash`, stdin is the script content, not the terminal, so `read` fails silently.

## Fix
Either:
1. Read from `/dev/tty` explicitly:
   ```bash
   read -p "Continue? [Y/n] " answer < /dev/tty
   ```
2. Or remove interactive prompts and use flags:
   ```bash
   ./install.sh --yes --mode=headless
   ```

## Acceptance Criteria
- [ ] `curl -sSL https://.../install.sh | bash` works without hanging
- [ ] Interactive prompts use `/dev/tty` or are skippable with flags
