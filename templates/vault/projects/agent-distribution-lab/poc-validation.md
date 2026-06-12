---
type: contract
parent: agent-distribution-lab
status: active
description: "Anti-hallucination contract for kanban cards whose deliverable is running code. POCs require independent validation by a different squad agent before the owner card can complete. Cross-profile rule — applies to P1, P2, P3 equally."
---

# POC Validation Contract

Sibling to [`profiles.md`](profiles.md) and [`ranker.md`](ranker.md). This
contract closes the gap they don't: the WS-lock atomic-side-effects rule
catches doc incompleteness, but neither catches the case where the owner
of a running-code card *writes a report claiming the POC produced
metric X*, without having actually produced metric X.

Threat model: LLM agents can confidently fabricate output values (p99
latencies, throughput numbers, log excerpts) when their loop terminates
before the code actually ran end-to-end. This is the highest-impact
failure mode the ranker doesn't currently see — the WS looks done, the
soundness rubric gives 5/5, results.md shows a fast lock, and the
fabricated number sits in the decision record forever.

Validation is the fix. The owner produces; a different agent verifies
the producing actually happened.

## What counts as a POC

A kanban card is a POC when its deliverable is **running code that
produces measurable output**. Concretely, one or more of:

- A binary / script / job that runs and emits metrics (p99, throughput,
  memory, etc.).
- A pipeline that consumes input and writes output files / DB rows /
  queue messages, where the *content* of the output is part of the
  acceptance criteria.
- A latency / load / capacity probe whose numbers feed an architectural
  decision (e.g., "is the index structure fast enough at target scale").
- Any card whose body says "verify X works locally" or "demonstrate Y
  with metrics" or "produce traces / logs showing Z".

A kanban card is **not** a POC when its deliverable is text, a decision,
a diagram, a design, or a research synthesis. Doc-only cards already get
peer-reviewed at WS-lock via the synthesis chain; they don't need this
second gate.

Edge cases:

- "Write code + show it compiles / tests pass" → NOT a POC; standard
  test runs already gate this.
- "Write code + show it produces output X when fed input Y" → POC.
- "Pick a tool by trying both A and B and reporting which is faster" →
  POC (the speed claim is the deliverable).
- "Read vendor docs and report whether feature X exists" → NOT a POC
  (research card; goes through normal Clio grounding review).

When in doubt, treat as POC. False positive cost: one extra validation
card. False negative cost: fabricated number lands in WS.md.

## Trigger mechanism

The owner declares the POC at create time:

```bash
hermes kanban create "H1: index PoC on synthetic dataset" \
  --tenant <ws-slug> \
  --assignee hephaestus \
  --poc \                               # ← this is the trigger
  --body "Build minimal index eval over a synthetic dataset at target scale. Report p99 + memory + index size."
```

If the `--poc` flag is not yet wired in this hermes-agent build, the
fallback is metadata in the card body: a line `poc: true` in the first
five lines of the body. The orchestrator (`default`) scans for this at
decomp time and treats it as the flag.

Orchestrator-side retroactive tagging: if a card was created without
`--poc` but the user or another agent notices it should have been, leave a
kanban comment `RETROACTIVE-POC` on the owner card. Same gating rules
apply from that point on; the owner card cannot complete until a validate
card is created and lands.

## Validator selection

**Floor rule (anti-collusion):** validator MUST be a different squad
agent than the POC owner. Same-agent self-validation is the exact
failure mode this contract exists to prevent.

**Selection process:** the orchestrator (`default`) picks the validator
when creating the paired validate card. Defaults by skill match:

| POC owner | POC nature | Default validator |
|---|---|---|
| Hephaestus | Running binary / pipeline / latency probe | Clio (evidence-grounding lens — pulls actual logs, checks metric plausibility) |
| Hephaestus | Architectural-correctness probe (e.g., "show the contract holds end-to-end") | `default` / Hermes (architecture lens) |
| Clio | Tool-comparison probe with real code | Hephaestus (execution lens) |
| `default` / Hermes | Anything (rare — Hermes usually doesn't own POCs) | Hephaestus |

Talaria does not validate — it's mechanical-edit-only by design. If
Talaria somehow owns a POC, that's a profile drift event; reroute the
POC to Hephaestus.

The orchestrator records the picked validator and the rationale in the
validate card's body.

## Validation depth

The validator picks the depth per card based on cost. Both modes are
acceptable; the choice is documented in the validate card body under a
`Mode:` header.

**Mode A — independent re-run from scratch (strongest):**
- Validator runs the POC end-to-end themselves: clones the owner's
  branch, builds, runs, captures their own metrics.
- Required if the POC is locally reproducible in <30 minutes and the
  numbers feed a Phase-1 / Phase-2 architectural lock.
- Validator's numbers must match the owner's within a documented
  tolerance (typically ±10% for latency, ±5% for throughput, exact
  match for counts).

**Mode B — artifact inspection + owner live demo (cheaper):**
- Validator reads the owner's logs, metric dumps, output files; then
  asks the owner (via kanban comment) to run the POC live and produce
  fresh artifacts.
- Validator compares the fresh artifacts to the reported numbers.
- Acceptable when re-running from scratch costs >30 minutes (multi-hour
  pipeline, prod-data-dependent, requires a non-trivial cluster).

**Mode C — log-only (weakest, only with explicit justification):**
- Validator reads the owner's reported logs and confirms internal
  consistency (timestamps line up, error rates match the claimed run
  duration, etc.) without re-execution.
- Allowed only when both Mode A and Mode B are infeasible (e.g., the
  POC required a prod-data sample now deleted). Validator must justify
  why A and B are not possible; that justification is visible to the
  ranker.

In all three modes, the validate card's output is a kanban comment on
the **owner card** containing:

1. The mode used and why.
2. The validator's re-derived (or re-observed) metrics, side-by-side
   with the owner's reported numbers.
3. Specific log excerpts the validator pulled themselves (not copied
   from the owner's report).
4. Anomalies, if any.
5. A clear PASS / FAIL verdict.

## Gating mechanism

The kanban schema has no native `validates` linkage column (see the
boards-feature gap note in
[`prompts/new-ws-bootstrap.md`](prompts/new-ws-bootstrap.md) step 2).
The link is operational, not schema-level:

1. **Pairing at create time:** when the orchestrator sees `--poc` (or
   `poc: true` in body), it immediately creates a paired validate card:
   ```bash
   hermes kanban create "VALIDATE: <owner card title>" \
     --tenant <ws-slug> \
     --assignee <picked validator> \
     --body "Validates owner card: <owner-card-id>. Owner: <agent>. ..."
   ```
   And drops a comment on the owner card naming the validate card id:
   ```bash
   hermes kanban comment <owner-card-id> "POC validate card: <validate-card-id>. Owner cannot complete until validator lands PASS."
   ```

2. **Owner card complete is blocked by orchestrator:** when the owner
   tries to `kanban complete <owner-card-id>`, the orchestrator (the
   `default` profile running the WS) checks for a `POC validate card:`
   comment on the owner card. If present, it looks up the validate
   card's status:
   - validate card not yet created → BLOCK; create one first.
   - validate card in `todo` / `running` / `blocked` → BLOCK with
     `hermes kanban comment <owner-card-id> "Waiting on POC validator
     (<validate-card-id>) before owner card can complete."` Owner card
     moves to `blocked` if it isn't already.
   - validate card complete with FAIL verdict → BLOCK; reopen owner card
     with the validator's reasons; do not allow complete until the
     owner fixes and re-validation lands.
   - validate card complete with PASS verdict → allow owner card to
     complete.

3. **No native enforcement** — this is human / orchestrator discipline,
   not a schema rule. If the orchestrator fails to enforce, the ranker
   catches it post-hoc (see "Ranker integration" below). Long-term,
   this should become a kanban-schema rule; until then, the discipline
   lives in Hermes's worker loop.

## Ranker integration

POC validation is folded into the existing **architectural soundness**
dim (dim 5 of the ranker), not a new top-level dim. Concretely:

- **Unvalidated POC closed as `done`** (owner completed without a
  paired validate card, or with the validate card still incomplete) →
  soundness cap at **3/5** for the entire WS, regardless of doc quality.
  Same shape as the existing profile-drift cap.
- **Validator-caught fabrication** (validate card lands FAIL with
  evidence the owner's numbers were not reproducible / not real) →
  soundness drops to **1/5** for the WS, plus an explicit incident in
  the `ws-log` "Profile drift incidents" section and a finding in
  `Findings worth keeping` flagging the fabrication pattern.
- **Validator caught nothing wrong** → no scorecard impact; this is
  the expected case and doesn't earn the WS extra points.

The ws-log scorecard template carries a `## POC validations` section
listing each POC card, its validator, the mode used, and the verdict.
This is read by the ranker to check the cap conditions above.

## Failure modes and anti-gaming

- **Owner skips `--poc` on a card that should have been a POC.** Caught
  by orchestrator inspection at decomp time (the routing table in
  profiles.md already requires `default` / decomposer to read every
  card); retroactive flag added; same gating from that point on.
- **Validator rubber-stamps.** Validator must paste actual log excerpts
  / re-derived numbers, not just write "PASS". A validate card whose
  comment lacks these is itself a rework event (returns to `running`
  with `hermes kanban comment <validate-card-id> "Validator output
  missing reproduced metrics — re-run."`).
- **Owner and validator are the same agent under a different label.**
  Floor rule prevents this. If a profile somehow puts the same agent
  on both sides (e.g., a future P-N profile with a single squad
  member), the contract requires the user to validate. This is a
  hard-stop; no POC is "self-validated."
- **Validator picks Mode C without justification.** Caught by the ws-log
  scorecard review — every Mode C validate card needs a one-line
  justification visible to the ranker.

## What this contract does NOT cover

- Mechanical edits dispatched to Talaria. Those are gated by Hephaestus's
  pre-existing review pass (audit before completing the parent card);
  they are not POCs.
- Research cards (Clio surveys, runbook reads). Their grounding is the
  citations dim of the ranker; that's already a separate check.
- Decisions / picks / locks. Those are gated by the swarm's verifier
  step in P3, and by Hermes's architecture-gate cards in P2. POCs may
  feed into a decision (and often do), but the decision itself is not
  a POC.

## Operational checklist for the orchestrator

Whenever decomposing a WS:

1. For every child card you create, ask: *is the deliverable running
   code that emits measurable output?* If yes → add `--poc`.
2. For every `--poc` card, immediately create the paired validate card
   with a different-agent assignee.
3. Drop the `POC validate card: <id>` comment on the owner card.
4. At the WS-lock synthesis step, scan all `--poc` cards on the board.
   Any owner card in `done` without a corresponding PASS-verdict
   validate card is a soundness cap event — record it in the ws-log
   before computing the scorecard.

## Memory

Findings worth keeping cross-session get linked here as the contract
gets exercised (validator-as-self-critique precedents, per-agent
scoring signals, fabrication incidents).

## Retroactive scope

None. Applies forward-only from adoption — from the next WS bootstrap
onward. WSes locked under a prior contract stay locked as-is.
