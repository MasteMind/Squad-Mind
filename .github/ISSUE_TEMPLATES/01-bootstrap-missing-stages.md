---
title: "Bootstrap stages 6–9 are documented but not implemented"
labels: ["bug", "high", "bootstrap"]
---

## Problem
`setup.md` describes 10 steps (0–9), but `bootstrap/` only ships scripts for stages 0–5. Stages 6–9 are:
- Step 6: Configure Delivery (Telegram/Slack/local)
- Step 7: Enable Auto-Start (systemd/screen/manual)
- Step 8: Seed Starter Projects (health/finance)
- Step 9: First-Run Simulation

The interview collects this data, but the bootstrap kit cannot act on it. Users must manually finish setup after the scripts stop.

## Impact
- Incomplete out-of-the-box experience
- Users confused why Telegram bots don't start
- No auto-start after reboot
- Starter projects require manual copy

## Proposed Fix
Implement missing stage scripts:

```
bootstrap/
├── 60-delivery.sh        # Write Telegram/Slack configs to ~/.hermes/profiles/
├── 70-autostart.sh       # Create systemd units or screen wrapper
├── 80-starter-projects.sh # Copy health/finance templates if enabled
└── 90-first-run.sh       # Validate brain/, print system summary
```

## Acceptance Criteria
- [ ] `60-delivery.sh` creates valid `~/.hermes/profiles/telegram.yaml`
- [ ] `70-autostart.sh` creates systemd units that survive reboot
- [ ] `80-starter-projects.sh` copies templates without duplicates on re-run
- [ ] `90-first-run.sh` validates `brain/hot.md` frontmatter and exits 0 on success
- [ ] `setup.md` updated to reference the new scripts
