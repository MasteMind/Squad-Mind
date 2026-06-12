---
type: index
parent: agent-distribution-lab
description: "One scorecard per WS. Filename is <ws-slug>.md. Template lives in prompts/new-ws-bootstrap.md step 4."
---

# WS Scorecards

One file per WS, named `<ws-slug>.md`. Created by Hermes during the
new-WS bootstrap (see [`../prompts/new-ws-bootstrap.md`](../prompts/new-ws-bootstrap.md)
step 4 for the canonical template).

## Lifecycle per file

1. **Pre-flight** filled at bootstrap (hypothesis, planned split, risks, scope freeze).
2. **Dispatch** table filled at first round of `hermes kanban create`.
3. **Mid-flight notes** appended as the WS runs.
4. **Post-flight scorecard** filled at WS-lock per [`../ranker.md`](../ranker.md).
5. **Row appended** to [`../results.md`](../results.md) on lock.

## Scorecard format

### Frontmatter

| Field | Meaning |
|---|---|
| `type` | always `ws-scorecard` |
| `parent` | always `agent-distribution-lab` |
| `ws_slug` | the WS slug (= filename, board label, tenant, project dir) |
| `profile` | assigned profile (`P1` \| `P2` \| `P3`), immutable once dispatch begins |
| `codex_available` | whether Hephaestus's profile points at the alternative orchestrator model (check `~/.hermes/profiles/hephaestus/config.yaml`) |
| `board` | kanban board slug (= ws_slug) |
| `started` | ISO date |
| `status` | `in-flight` → `locked` (or `abandoned`) |

### Sections

- **`## Pre-flight`** — the hypothesis half, written BEFORE any dispatch:
  - **Hypothesis:** what you expect this profile to do on this WS, and why
    this profile×WS pairing was picked.
  - **Planned task split:** the intended decomposition per the profile's
    rules (research → Clio, spikes/integration → Hephaestus, gates →
    Hermes/`default`, mechanical → Talaria), with expected card counts.
  - **Risks specific to this profile×WS pairing.**
  - **Scope freeze:** copied verbatim from the bootstrap prompt — this is
    what the ranker holds the WS to.
- **`## Dispatch (filled at bootstrap)`** — table of first-round cards:
  task id, assignee, title, depends-on.
- **`## Mid-flight notes`** — append-only; anything ranker-relevant
  (decomposition surprises, recoveries, routing observations).
- **`## Post-flight scorecard (filled at WS-lock)`** — the eval half, the
  6 ranker dims plus composite:
  time-to-lock (h), tokens (k), user interventions, rework count,
  architectural soundness (1–5), research grounding (citations/decision),
  composite (recomputed after the results.md insert).
- **`## POC validations`** — one row per `--poc` card: owner card, owner
  agent, validate card, validator agent, mode (A/B/C), verdict
  (PASS/FAIL/pending). Read by the ranker to apply the
  [`../poc-validation.md`](../poc-validation.md) soundness caps.
- **`## Profile drift incidents`** — deviations from the assigned profile,
  why, and whether the soundness cap applies. Also any POC card closed
  without a PASS-verdict validate card.
- **`## Findings worth keeping`** — patterns, surprises, anti-patterns to
  feed back into [`../profiles.md`](../profiles.md).

## Archiving

When a WS run is deleted or re-run before lock, move its scorecard to
`_archived/<slug>_<YYYY-MM-DD>.md` so the slug frees up for re-bootstrap
and the ranker never reads stale runs.
