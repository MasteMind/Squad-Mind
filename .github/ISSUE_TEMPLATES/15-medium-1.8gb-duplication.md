---
title: "[MEDIUM] 1.8GB duplicate hermes-agent in Argus profile"
labels: ["performance", "medium", "hermes"]
---

## Description
`~/.hermes/profiles/argus/hermes-agent/` is a 1.8GB duplicate of the shared `~/.hermes/hermes-agent/`. This wastes disk space and causes confusion about which binary is authoritative.

## Fix
1. Delete the duplicate:
   ```bash
   rm -rf ~/.hermes/profiles/argus/hermes-agent/
   ```
2. Ensure Argus uses the shared binary via PATH:
   ```bash
   export PATH="$HOME/.hermes/bin:$PATH"
   ```
3. Add a check to prevent future duplication in bootstrap

## Acceptance Criteria
- [ ] `~/.hermes/profiles/argus/` contains no `hermes-agent/` directory
- [ ] All agents use shared `~/.hermes/hermes-agent/`
- [ ] Bootstrap prevents duplicate agent installations
