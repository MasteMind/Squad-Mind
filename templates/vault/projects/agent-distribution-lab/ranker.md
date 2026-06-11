---
type: ranker
parent: agent-distribution-lab
status: active
description: "6-dimension scorecard for ranking distribution profiles. Quality-first weighting (soundness/grounding/rework dominate). Composite is a weighted z-score across all completed WSes."
---

# Ranker — How Profiles Get Scored

Captured per WS at the moment of WS-lock (or WS-ship, whichever the WS
defines as terminal). Filled into `ws-log/<slug>.md` and then propagated
to [`results.md`](results.md) as a single row.

## Dimensions

| # | Dim | Direction | How captured | Scale |
|---|-----|-----------|--------------|-------|
| 1 | **time-to-lock** | lower-better | `hermes kanban runs` on the parent task → calendar time from `created` event to `complete` event on the synthesis/lock task | hours |
| 2 | **total tokens** | lower-better | Sum across all agents on this board. Pull from the llm-cli-proxy-link logs at `~/.hermes/llm-cli-proxy-link/logs/` filtered by board slug, or `hermes kanban stats` if that lands token accounting first | thousands of tokens |
| 3 | **user interventions** | lower-better | Count of kanban comments authored by `default` profile that are *not* part of the planned dispatch (i.e., clarifications, corrections, escalation responses). Heuristic: any `default`-authored comment on a task that `default` does not own | integer count |
| 4 | **rework count** | lower-better | Tasks moved from `done` back to `ready`/`todo` + decisions reversed in `WS.md` (or equivalent) after first being locked. Pulled from `hermes kanban runs` (re-attempts) + manual decision-log read | integer count |
| 5 | **architectural soundness** | higher-better | The user's post-WS 1–5 score, with anchored rubric below. Includes POC-validation gate (see [`poc-validation.md`](poc-validation.md)): unvalidated POCs cap soundness at 3; validator-caught fabrication drops it to 1. | 1–5 |
| 6 | **research grounding** | higher-better | Count of distinct external citations (URLs, doc paths, ADR refs) per locked decision in the final WS doc | citations/decision (decimal) |

### Soundness rubric (dim 5)

| Score | Meaning |
|-------|---------|
| 5 | Every locked decision has explicit tradeoffs, named alternatives, and a doc citation. Would defend as-is in a Staff+ design review. |
| 4 | Tradeoffs and citations present for ≥80% of decisions; remaining are obvious/low-stakes. |
| 3 | Decisions are defensible but several lack explicit alternatives or citations. Would survive a friendly review. |
| 2 | At least one decision relies on Hermes/Hephaestus assertion without a citation. Would not survive an adversarial review. |
| 1 | Multiple decisions are agent-fabricated. Re-work required before any external review. |

## Composite formula

Quality-first weighting:

```
composite = 0.30 * z(soundness)
          + 0.20 * z(grounding)
          - 0.20 * z(rework)
          - 0.15 * z(interventions)
          - 0.10 * z(time-to-lock)
          - 0.05 * z(tokens)
```

`z(x)` = z-score of dim `x` across all completed WSes (per-dim mean and
stdev recomputed each time a new row lands in [`results.md`](results.md)).
Higher-better dims add; lower-better dims subtract.

A profile's score is the mean composite of its WSes.

## When to compute

- Single WS scorecard: at WS-lock. Goes into `ws-log/<slug>.md`.
- Composite recompute: every time a new row lands in `results.md`.
- Profile ranking: requires ≥1 WS on each ranked profile and ≥3 total
  WSes; otherwise standings are flagged as "insufficient data".

## What does NOT go into the ranker

- Subjective vibes ("felt fast", "felt thorough"). If it can't be derived
  from kanban/proxy logs or a 1–5 rubric, it goes in `notes`, not the
  scorecard.
- Anything captured only in agent transcripts that isn't reflected on
  the kanban board. The board is the source of truth.
- Token cost in dollars. We track raw tokens; the $/token rate changes
  too often and conflates a routing question with a pricing question.

## Anti-gaming notes

- Profile drift (P2 silently pulling Hermes in for non-architecture-gate
  decisions, or P1 letting Hephaestus decompose) is a manual demerit on
  soundness (cap at 3) plus a `notes` entry. Otherwise a P2 WS that
  secretly ran like P1 would look like P2 worked great.
- WS scope must be locked at bootstrap (in the pre-flight section of
  `ws-log/<slug>.md`). Mid-WS scope reduction inflates speed/lowers
  rework artificially.
- POC fabrication is the highest-impact anti-gaming concern. Per
  [`poc-validation.md`](poc-validation.md): any card whose deliverable
  is running code that emits measurable output must be paired with a
  validate card owned by a different squad agent before the owner card
  can complete. Unvalidated POC closed as done → soundness cap at 3/5
  for the WS. Validator-caught fabrication → soundness drops to 1/5
  plus an explicit incident in the ws-log. Without this gate, an agent
  that fabricates p99 numbers looks identical to one that measured them.

## Memory

Findings worth keeping cross-session get linked here as the lab
accumulates baselines (e.g., the first P1 WS this lab calibrates against).
