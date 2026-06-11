---
type: marker
parent: agent-distribution-lab
status: active
description: "Canonical agent-distribution profiles. Each new WS is assigned exactly one profile. Profile ID is recorded in ws-log/<slug>.md and is immutable for that WS once dispatch begins."
---

# Distribution Profiles (the Marker)

Each WS runs under exactly one profile. The profile dictates **who owns
the parent task, who decomposes, who implements, who escalates to whom**.
Clio is common across all profiles for research and runbook navigation.
Talaria is common across all profiles for mechanical single-file edits
dispatched by whoever owns implementation.

> Routing pitfall (already burned us once): when a task belongs to
> Hermes-the-architect, the kanban assignee MUST be `default`, not
> `hermes`. `hermes` is in the dispatcher's reserved-name set and tasks
> silently end up in `skipped_nonspawnable` with no events.
> See [[feedback_hermes_assignee_is_default]].

---

## P1 — `hermes-led` (baseline)

**Who owns the parent:** Hermes (`--assignee default`).

**Decomposition:** Hermes only. Hermes breaks the WS into:
- Research children → Clio (3-day timebox each)
- Spike / PoC children → Hephaestus (sandbox, narrow scope)
- Synthesis child → Hermes, blocked on all research + spike children

**Implementation:** Hephaestus performs only the spike tasks Hermes
dispatched. No autonomous multi-file integration.

**Escalation:** Hephaestus surfaces blockers as kanban comments; Hermes
re-decomposes or unblocks.

---

## P2 — `hephaestus-led` (alternative-orchestrator test)

**Who owns the parent:** Hephaestus.

**Decomposition:** Hephaestus only. Hephaestus breaks the WS into:
- Research children → Clio (same 3-day timebox)
- Implementation/integration children → Hephaestus self-claims
- Mechanical children → Talaria (via Hephaestus)
- Architecture-gate children → Hermes (`--assignee default`), narrow scope:
  *"Lock decision X with rationale and doc citations"*

**Implementation:** Hephaestus owns multi-file integration end-to-end.

**Escalation:** Hephaestus escalates to Hermes only at named architecture
gates (e.g., "pick storage engine", "lock SLA"). Hermes returns a locked
decision; does not take over the parent.

**Hypothesis being tested:** an alternative coding-first model as
orchestrator is at least as good as the default architect model, *with
the bonus* of much cheaper per-token implementation sitting in the same
brain.

**Caveat until the alternative model is wired:** if
`~/.hermes/profiles/hephaestus/config.yaml` still points at the same
model family as Hermes, P2 runs are tagged `codex_available: false` in
the scorecard so they don't muddy the eventual cross-model comparison.

---

## P3 — `balanced-tot` (Team-of-Thoughts routing)

**Who owns the parent:** Hermes (`--assignee default`), but **only as
router**, not as decomposer-of-everything.

**Decomposition:** Per the routing table below. Hermes runs the router;
Hephaestus and Clio each decompose their own assigned slices further if
needed.

### Routing table

| Task characteristic | Owner |
|---|---|
| Greenfield architecture, contract design, runbook authoring, ADR drafting | Hermes |
| Multi-file integration, code generation, refactor, scaffolding, test-suite work | Hephaestus |
| External tech survey, runbook navigation, vendor doc reasoning, peer-evidence collection | Clio |
| Single-file mechanical edits, renames, unit-test additions | Talaria (via Hephaestus) |
| **Decision with ≥2 defensible answers** | `hermes kanban swarm`: workers=Hermes+Hephaestus+Clio in parallel, verifier=Hermes, synthesizer=Hermes |

The swarm verb is the operationalisation of the ToT paper — when a
question has multiple defensible answers, don't pick one agent; spawn
all three in parallel and synthesize.

**Implementation:** Distributed per the routing table.

**Escalation:** Each agent escalates blockers as kanban comments on the
relevant card. Router (Hermes) reassigns if the original owner is wrong.

**Hypothesis being tested:** Per the paper — strategic heterogeneous
routing beats either single-model orchestration on the cost-quality
Pareto.

---

## Deferred profiles (not in current rotation)

**P4 `hephaestus-solo`** — Hephaestus does everything except Clio research.
No Hermes anywhere. Pure control for "is the architect role pulling its
weight?" Held until [D-AGL-001](README.md#open-decisions) is decided.

**P5 `hermes-solo`** — Hermes does everything including implementation
(via native Read/Edit/Write tools, no kanban dispatch to Hephaestus).
Single-orchestrator baseline. Held until D-AGL-001.

---

## Profile assignment rules

1. **At WS bootstrap**, the user either picks the profile explicitly or asks
   Hermes to round-robin from [`results.md`](results.md) (least-tested
   profile wins; ties broken by alphabetical ID).
2. **Profile is immutable** once the first kanban task on the board moves
   to `running`. If the profile turns out to be a bad fit, that itself is
   a finding — log it in the scorecard's `notes` and complete the WS on
   the originally-assigned profile if at all possible.
3. **Profile drift** (Hermes silently doing Hephaestus's work or vice
   versa) is a scorecard demerit, not a bug fix. Catch it in the scorecard's
   `notes` section.
