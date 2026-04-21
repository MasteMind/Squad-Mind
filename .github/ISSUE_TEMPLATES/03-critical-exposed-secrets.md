---
title: "[CRITICAL] API keys and tokens exposed in runtime files"
labels: ["security", "critical", "hermes"]
---

## Description
Multiple locations in `~/.hermes/` and the Home-Brain vault contain exposed secrets that should be rotated immediately.

## Exposures Found

| File | Secret Type | Severity |
|------|-------------|----------|
| `~/.hermes/.env` | Multiple API keys | Critical |
| `~/.hermes/bin/consult-solon` | Hardcoded key in script | Critical |
| `~/.hermes/auth.json` | OAuth tokens | Critical |
| `brain/hot.md` | Telegram chat ID + bot token | High |
| `agents/*/MEMORY.md` | May contain conversation leakage | Medium |

## Fix
1. **Rotate ALL API keys** immediately — treat any key found in these files as compromised
2. Move secrets to `~/.hermes/.env` with `chmod 600`
3. Remove hardcoded keys from scripts — source from `.env`
4. Redact Telegram IDs/tokens from `brain/hot.md`
5. Enable `privacy.redact_pii: true` in Hermes config
6. Add `.env` and `auth.json` to `.gitignore` (if not already)

## Acceptance Criteria
- [ ] All API keys rotated
- [ ] No secrets in scripts under `~/.hermes/bin/`
- [ ] `brain/hot.md` contains no tokens or IDs
- [ ] `grep -r 'sk-ant\|AIza\|sk-or-' ~/.hermes/` returns nothing
