---
type: project
status: active
owner: "{{USER_NAME}}"
agents:
  - Hermes
  - Hephaestus
  - Clio
  - Talaria
description: "Rank agent-distribution profiles across parallel WSes, one Kanban board per WS. Lab harness for picking the right squad topology per WS."
---

# Agent Distribution Lab

**Status:** active
**Owner:** {{USER_NAME}}
**Started:** <fill at adoption>
**KR cycle:** <fill at adoption>
**Pillar:** <parent initiative this rolls up to, if any>

Existence justified by one question:

> Across a real WS — research-heavy, decision-heavy, multi-doc — which
> Hermes ↔ Hephaestus split produces the most defensible, citable design
> with the fewest user interventions?

## Why run it

- More than one orchestrator-capable model family can be wired into the
  Hephaestus profile, so Claude-as-orchestrator vs
  alternative-model-as-orchestrator is comparable on the same class of WS.
- `hermes kanban boards` and `hermes kanban swarm` are first-class CLI
  features — one board per WS is the supported topology, not a hack.
- Team of Thoughts (arXiv 2602.16485): heterogeneous teams beat
  single-agent scaling *only when routing is strategic, not random*. P3
  operationalises this.

## How it works

1. Every new WS the user kicks off becomes one experiment.
2. The user pastes [`prompts/new-ws-bootstrap.md`](prompts/new-ws-bootstrap.md)
   at the top of the session, picking (or letting Hermes pick) a profile
   from [`profiles.md`](profiles.md).
3. Hermes creates a dedicated Kanban board, the vault project
   directory, and the per-WS scorecard under `ws-log/<slug>.md`.
4. Work runs on that board under the assigned profile.
5. At WS-lock or WS-ship, the scorecard gets filled per
   [`ranker.md`](ranker.md) and a row appears in
   [`results.md`](results.md).
6. After 3+ WSes complete on at least 2 profiles, composite scores get
   computed and the winning profile becomes the default until disproven.

## Current standings

No WSes completed yet. See [`results.md`](results.md) — standings stay
"insufficient data" until ≥1 WS on each ranked profile and ≥3 total WSes.

## Completed WSes

| WS slug | Profile | Board | Started | Locked | Soundness | Grounding |
|---|---|---|---|---|---|---|

_(Hermes moves rows here from the In-flight table at WS-lock.)_

## In-flight WSes

| WS slug | Profile | Board | Started | Status |
|---|---|---|---|---|

_(Hermes appends a row per new WS during bootstrap; moves to Completed table at WS-lock.)_

## Artifacts

- [`profiles.md`](profiles.md) — the marker. 3 named distribution profiles.
- [`ranker.md`](ranker.md) — the eval rubric. 6 dimensions + composite formula.
- [`poc-validation.md`](poc-validation.md) — anti-hallucination contract for running-code cards. Cross-profile, forward-applying.
- [`results.md`](results.md) — append-only eval log, one row per completed WS.
- [`prompts/new-ws-bootstrap.md`](prompts/new-ws-bootstrap.md) — paste-at-start prompt template.
- `ws-log/<slug>.md` — per-WS pre-flight hypothesis + post-flight scorecard.

## Open decisions

- **D-AGL-001** — Include pure-solo controls (P4 hephaestus-solo, P5
  hermes-solo)? Deferred until 2–3 WSes complete on P1/P2/P3 and we see
  whether the comparison is muddy.
- **D-AGL-002** — When to retire P1 as baseline. Open until composite
  scores show ≥1.5σ separation across ≥3 replicates.
- **D-AGL-003** — Whether to compare alternative-model-Hephaestus vs
  Claude-as-Hephaestus *within* P2. Currently the marker assumes
  whatever model the Hephaestus profile points at. May need to split P2
  into P2a/P2b once both are available.
