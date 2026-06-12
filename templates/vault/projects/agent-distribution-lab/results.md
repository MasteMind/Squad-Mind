---
type: log
parent: agent-distribution-lab
status: active
description: "Append-only results log. One row per WS at lock. Composite scores recomputed each insert. Newest at top."
---

# Results Log

One row per completed WS. Pull dim values from `ws-log/<slug>.md`. Recompute
z-scores and per-profile means each time a new row lands.

## Completed WSes

Newest at top. Composite deferred until N≥3 total (per ranker §When to compute).

| WS slug | Profile | Time-to-lock (h) | Tokens (k) | Interventions | Rework | Soundness | Grounding | Composite | Notes |
|---|---|---|---|---|---|---|---|---|---|

_(No rows yet — the first row lands at the first WS-lock.)_

## In-flight WSes

| WS slug | Profile | Board | Started | Hypothesis |
|---|---|---|---|---|

_(Hermes appends a row per new WS during bootstrap; moves to Completed at WS-lock.)_

## Per-profile standings (composite mean)

| Profile | WSes (N) | Composite mean | Notes |
|---------|----------|----------------|-------|

_Standings update rule:_ requires ≥1 WS on each ranked profile AND ≥3
total WSes; otherwise standings are flagged "insufficient data".

## Decisions made from results

_Empty until 3+ WSes complete._
