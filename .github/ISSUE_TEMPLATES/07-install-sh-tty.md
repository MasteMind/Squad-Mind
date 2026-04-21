---
title: "install.sh breaks when piped via curl | bash"
labels: ["bug", "low", "bootstrap"]
---

## Problem
`scripts/install.sh` uses `read` for interactive prompts. When piped (`curl | bash`), stdin is the script content, not the terminal, so prompts fail silently.

## Proposed Fix
Either read from `/dev/tty`:
```bash
read -p "Continue? [Y/n] " answer < /dev/tty
```
Or support flags for non-interactive mode:
```bash
./install.sh --yes --mode=headless --providers=claude,gemini
```

## Acceptance Criteria
- [ ] `curl -sSL .../install.sh | bash` works without hanging
- [ ] Non-interactive mode documented in README
