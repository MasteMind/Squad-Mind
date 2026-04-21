---
title: "[MEDIUM] agents/hermes/SOUL.md missing 4 agents from roster"
labels: ["quality", "medium", "vault"]
---

## Description
`agents/hermes/SOUL.md` (or equivalent roster file) doesn't list all active agents:
- Argus (monitor)
- Asclepius (health)
- Solon (reasoning)
- Lab-Assistant (local)

## Fix
Update the roster to include all active agents with their:
- Role
- Provider
- Model
- Purpose
- Delivery mechanism (if any)

## Acceptance Criteria
- [ ] All 8 agents documented in roster
- [ ] Each agent has a corresponding `agents/<name>/SOUL.md`
- [ ] Roster matches `AGENT_ROSTER.md` in vault
