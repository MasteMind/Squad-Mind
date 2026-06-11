---
name: run-poc
description: "Governed POC working session from chat: scope freeze, lab profile pick, mandatory vault project bootstrap, tenant-isolated kanban dispatch, cross-agent POC validation gate, distill to the brain, archive the workspace."
version: 1.0.0
author: Squad-Mind
license: MIT
metadata:
  hermes:
    tags: [poc, working-session, kanban, distribution-lab, validation]
prerequisites:
  commands: [hermes]
---

# Run-POC — Governed POC Working Session

Playbook for the orchestrator (Hermes, dispatcher-visible as `default`). A human
asks for a POC in chat; you run the whole session under the agent-distribution-lab
governance machinery. Paths below are relative to the vault root.

## When to Use

Trigger phrasings: "poc", "proof of concept", "evaluate X vs Y", "spike",
"benchmark", "try out", "working session", "can we measure". Example:
`@squad poc "evaluate engine A vs engine B for event dedup"`.

## When NOT to Use

- Pure research / doc questions → dispatch a normal research card to Clio.
- Single-file mechanical edits → normal kanban routing.
- Decisions with no running code involved → standard WS flow (`projects/agent-distribution-lab/prompts/new-ws-bootstrap.md`).

## Step 1 — Confirm scope, pick the lab profile

1. Echo a one-paragraph **scope freeze** back to the requesting thread; ask a
   clarifying question only if the ask is genuinely ambiguous.
2. Pick a `<slug>`: lowercase-kebab, derived from the ask. It doubles as the
   kanban tenant, the vault project dir, and the ws-log name.
3. Pick the distribution profile: default comes from `setup_answers.yaml`
   `lab.default_profile`. `auto` = round-robin the least-tested profile per
   `projects/agent-distribution-lab/results.md`. P1 (hermes-led) / P2
   (hephaestus-led) / P3 (balanced-tot) semantics live in
   `projects/agent-distribution-lab/profiles.md`. Tell the requester which
   profile you picked and why. Profile is immutable once dispatch begins.

## Step 2 — Bootstrap the vault project (MANDATORY, before any dispatch)

Per the bootstrap rule in `projects/README.md`: **no kanban card exists before
the project home does.** Create:

- `projects/<slug>/README.md` — Status / Owner / Started / KR cycle / Pillar /
  Source docs, plus the scope freeze.
- `projects/<slug>/notes/` — source-doc copies, research drops.
- `projects/<slug>/WS.md` once the session is active.

Also write the pre-flight scorecard at
`projects/agent-distribution-lab/ws-log/<slug>.md` (template in
`prompts/new-ws-bootstrap.md` step 4) and append an In-flight row to
`results.md`.

## Step 3 — Create tenant-isolated kanban cards

- Every `hermes kanban create` and `hermes kanban swarm` call MUST carry
  `--tenant <slug>` — the tenant flag is the actual isolation lever.
- `--assignee` per the chosen profile's routing rules (`profiles.md`).
- **Reserved-name rule:** orchestrator-owned cards use `--assignee default`,
  never `hermes` — `hermes` is reserved and the dispatcher silently skips it.
- **Stamp the requester:** put a `requested_by: <platform>:<user-id> (<display name>)`
  line in every card body. The upstream `created_by` stamping patch may not be
  merged in your build — the body line is the durable record either way.

```bash
hermes kanban create "H1: index PoC on synthetic dataset" \
  --tenant <slug> --assignee hephaestus --poc \
  --body "requested_by: slack:U012345 (Alex). Build minimal index eval ... report p99 + memory."
```

## Step 4 — Pair every POC card with a validate card

Contract: `projects/agent-distribution-lab/poc-validation.md`. A card is a POC
when its deliverable is **running code that emits measurable output**.

- Flag it at create time with `--poc` (fallback: `poc: true` in the first five
  lines of the body).
- Immediately create the paired card `VALIDATE: <owner title>`, same
  `--tenant`, assigned to a **different squad agent** per the
  validator-selection table in `poc-validation.md` (Talaria never validates).
- The validator documents its depth in the validate card: Mode A (independent
  re-run), Mode B (artifact inspection + live demo), or Mode C (log-only, with
  explicit justification).
- Drop a `POC validate card: <validate-id>` comment on the owner card.

## Step 5 — Gate completion

The owner card cannot `complete` until its validate card lands **PASS**:

- Validate card pending → owner card blocks at the complete boundary.
- Validate card FAIL → reopen the owner card with the validator's reasons;
  re-validate after the fix.
- Closing an unvalidated POC as done caps the WS soundness score at 3/5;
  validator-caught fabrication drops it to 1/5 (`ranker.md`).

## Step 6 — Distill and report back

1. Update `projects/<slug>/README.md` status; lock outcomes in
   `projects/<slug>/decisions.md` (date + decision + rationale, append-only).
2. Fill the post-flight scorecard in
   `projects/agent-distribution-lab/ws-log/<slug>.md` per `ranker.md`,
   including the POC-validations table, and move the row to Completed in
   `results.md`.
3. Post to the requesting thread: a 3–5 line summary, the verdict, and the
   brain permalink to `projects/<slug>/` (the brain repo's hosted URL when one
   exists), addressed to the requesting human from Step 3.

## Step 7 — Archive the workspace

The vault project stays — it is the durable record. The kanban workspace is
what gets cold-archived once all cards are done:

- **Server:** `deploy/scripts/archive-tenant.sh <slug>` (refuses while
  non-done cards exist; verifies the archive before removing anything).
- **Laptop:** `tar --zstd -cf <slug>-$(date +%F).tar.zst -C ~/.hermes/kanban/workspaces <slug>*`
  then remove the workspace dirs.

Move `projects/<slug>/` to `projects/_archived/<slug>_<YYYY-MM-DD>/` only when
the project is fully closed; a shipped POC that still gets cited stays put with
`Status: shipped`.
