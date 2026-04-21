---
title: "[MEDIUM] Hermes fallback provider configured but invalid"
labels: ["bug", "medium", "hermes"]
---

## Description
`credential_pool_strategies: kimi-coding: fill_first` references a fallback that either:
- Has no valid API key
- Points to a non-existent provider
- Creates an authentication cascade when primary fails

## Fix
1. Remove `kimi-coding` as fallback if no valid key exists
2. Configure a working fallback:
   - `ollama` local model (no API key needed)
   - Another provider with a verified key
   - Or remove the fallback entirely (fail fast)
3. Add fallback validation to smoke test

## Acceptance Criteria
- [ ] `config.yaml` has no fallback referencing invalid providers
- [ ] Smoke test validates fallback connectivity if configured
- [ ] If no fallback, Hermes fails gracefully with clear error
