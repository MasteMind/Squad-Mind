---
title: "[HIGH] Bootstrap stages 6–9 are documented but not implemented"
labels: ["bug", "high", "bootstrap"]
---

## Description
`setup.md` documents 10 steps (0–9), but `bootstrap/` only has scripts for stages 0–5. Stages 6–9 are:
- Step 6: Configure Delivery (Telegram/Slack)
- Step 7: Enable Auto-Start (systemd/screen)
- Step 8: Seed Starter Projects (health/finance)
- Step 9: First Run simulation

The interview collects this data but the bootstrap can't act on it.

## Impact
- Users must manually configure delivery after bootstrap
- No auto-start setup = agents don't survive reboot
- Starter projects require manual copy
- No first-run validation

## Fix
Implement missing stage scripts:

```
bootstrap/
├── 60-delivery.sh        # Telegram bot config, webhook setup
├── 70-autostart.sh       # systemd units or screen wrapper
├── 80-starter-projects.sh # Copy health/finance templates
└── 90-first-run.sh       # Mock orchestrator, validate brain/
```

## Acceptance Criteria
- [ ] Running `60-delivery.sh` creates `~/.hermes/profiles/telegram.yaml`
- [ ] Running `70-autostart.sh` creates systemd units that start on boot
- [ ] Running `80-starter-projects.sh` copies templates without duplicates
- [ ] Running `90-first-run.sh` validates `brain/hot.md` and prints summary
