---
type: prompt
parent: agent-distribution-lab
status: active
description: "Paste-at-start prompt for any new WS that should run as an agent-distribution-lab experiment. Hermes consumes this and bootstraps the board, project dir, and pre-flight scorecard."
---

# New-WS Bootstrap Prompt

Copy everything between the `===PROMPT START===` and `===PROMPT END===`
markers below into the first message of a new Hermes session. Fill the
bracketed fields. Leave the rest verbatim.

---

===PROMPT START===

New WS for the agent-distribution-lab project.

- **WS title:** [<one-line title>]
- **WS slug:** [<lowercase-kebab>] (used for kanban board, project dir, ws-log)
- **PFS / source doc(s):** [<absolute path(s)>, or "none — greenfield">]
- **Profile to test:** [<one of: P1 | P2 | P3 | auto>]
  - `auto` = round-robin from results.md, least-tested profile wins
- **WS-lock definition:** [<what "done" means for this WS, e.g.,
  "WS.md locked, all Q1–Qn answered, kanban parent complete">]
- **Scope freeze:** [<one-paragraph scope statement; this is what the
  ranker holds you to — mid-WS expansion is OK, mid-WS reduction is a
  ranker demerit>]

Hermes — bootstrap this WS as an agent-distribution-lab experiment:

1. **Read the lab contracts:**
   - `{{VAULT_PATH}}/projects/agent-distribution-lab/profiles.md`
     — apply the assigned profile's rules (or, if profile=auto, pick per
     results.md and tell me which you picked + why).
   - `{{VAULT_PATH}}/projects/agent-distribution-lab/ranker.md`
     — internalise the 6 dims you'll be scored on.
   - `{{VAULT_PATH}}/projects/agent-distribution-lab/poc-validation.md`
     — anti-hallucination gate for any card whose deliverable is running
     code that emits measurable output. Forward-applying from adoption.
     Every POC card needs `--poc` at create + a paired validate card
     owned by a different squad agent before the owner card can complete.

2. **Create the dedicated Kanban "board" (cosmetic) AND set the tenant
   namespace (load-bearing):**
   ```
   hermes kanban boards create <ws-slug> --name "<WS title>"
   hermes kanban boards switch <ws-slug>
   hermes kanban boards show   # confirm you switched
   ```
   ⚠️ **Boards-feature gap (as of this hermes-agent build):** the boards
   verbs above only persist metadata to `~/.hermes/kanban/boards/<slug>/`
   — the `tasks` table has NO `board` column, so `kanban create` cannot
   pin tasks to a board (the `--board` flag, `boards switch`, and
   `HERMES_KANBAN_BOARD` env var are all silently ignored on writes).
   The actual isolation lever is `--tenant <ws-slug>` on EVERY
   `kanban create` and `hermes kanban swarm` call. Filter views via
   `hermes kanban list --tenant <ws-slug>`.

   So in practice: still run the `boards create/switch` for the
   dashboard label, but **MUST** add `--tenant <ws-slug>` to every
   create/swarm call below. If you forget, backfill via:
   ```
   sqlite3 ~/.hermes/kanban.db "UPDATE tasks SET tenant='<ws-slug>' WHERE id IN ('t_xxx', ...);"
   ```

   Surface the WS slug back to me (it doubles as the tenant + board
   label + project-dir name).

3. **Create the vault project entry** per the bootstrap rule in
   `{{VAULT_PATH}}/agents/Hermes/AGENTS.md` §5:
   - `{{VAULT_PATH}}/projects/<ws-slug>/README.md` with Status/Owner/Started/
     KR cycle/Pillar/Source docs.
   - `{{VAULT_PATH}}/projects/<ws-slug>/notes/` for source-doc copies + research.
   - Link source docs and copy the PFS into `notes/source-pfs.md` if
     applicable.

4. **Write the pre-flight scorecard** at
   `{{VAULT_PATH}}/projects/agent-distribution-lab/ws-log/<ws-slug>.md`
   using the template below:

   ```markdown
   ---
   type: ws-scorecard
   parent: agent-distribution-lab
   ws_slug: <ws-slug>
   profile: <P1|P2|P3>
   codex_available: <true|false>   # check ~/.hermes/profiles/hephaestus/config.yaml model
   board: <ws-slug>
   started: <ISO date>
   status: in-flight
   ---

   ## Pre-flight

   **Hypothesis:** <what you expect to see under this profile for this WS>
   **Planned task split:** <list, per profile rules>
   **Risks specific to this profile×WS pairing:** <e.g., "P2 + heavy
   research WS may starve Hephaestus on architecture context">
   **Scope freeze:** <copied from prompt>

   ## Dispatch (filled at bootstrap)

   <ASCII table of first-round tasks: id, assignee, title, depends-on>

   ## Mid-flight notes

   <append as the WS runs; anything ranker-relevant>

   ## Post-flight scorecard (filled at WS-lock)

   - time-to-lock (h): <>
   - tokens (k): <>
   - user interventions: <>
   - rework count: <>
   - architectural soundness (1–5): <>
   - research grounding (citations/decision): <>
   - composite (recomputed after results.md insert): <>

   ## POC validations

   <one row per --poc card on this board>
   | owner card | owner agent | validate card | validator agent | mode (A/B/C) | verdict |
   |---|---|---|---|---|---|
   | <t_xxx> | <agent> | <t_yyy> | <agent> | <A re-run / B artifact+demo / C log-only> | <PASS/FAIL/pending> |

   ## Profile drift incidents

   <any case where the WS deviated from the assigned profile, why,
   and whether the ranker should apply the soundness cap. Also: any
   POC card closed without a paired validate card landing PASS — that
   applies the poc-validation cap per poc-validation.md>

   ## Findings worth keeping

   <patterns, surprises, anti-patterns to feed back into profiles.md>
   ```

5. **Dispatch the first round of tasks**, per the assigned profile's
   rules in profiles.md. Reminders:
   - Hermes-owned tasks use `--assignee default`, NEVER `--assignee hermes`.
   - **Every `kanban create` and `kanban swarm` call MUST include
     `--tenant <ws-slug>`** — this is the actual isolation lever (see
     step 2's gap note). Skipping it dumps the task into the global
     pool with other WSes' tasks.
   - For P3, when a decision has ≥2 defensible answers, use
     `hermes kanban swarm --tenant <ws-slug>` with workers=hermes+hephaestus+clio.
   - **Orchestrator pattern:** parent / decomposition cards complete
     after dispatching their children — they do not "wait" via block.
     The synthesis / WS-lock card is a SEPARATE downstream card with
     `--parent` linkage to all of its inputs (auto-blocks until they
     all complete).
   - **POC cards** (deliverable = running code that emits measurable
     output): create with `--poc` (fallback: `poc: true` in the first 5
     lines of `--body`). For every `--poc` card, immediately create a
     paired `VALIDATE: <title>` card assigned to a different squad
     agent (selection per the table in `poc-validation.md`), tenant
     scoped, and drop a `POC validate card: <validate-id>` comment on
     the owner card. The owner card cannot `complete` while the
     validate card is incomplete or in FAIL — orchestrator enforces at
     the complete boundary. See `poc-validation.md` for the full
     contract, validator-selection table, and the three validation
     depth modes (A re-run / B artifact+demo / C log-only).

6. **Surface back to me:**
   - The board slug.
   - The vault project dir path.
   - The ws-log path.
   - The first-round task IDs (parent + children) with assignee.
   - If profile=auto, why you picked what you picked.
   - Any pre-flight concerns about the profile × WS fit.

7. **Append a row** to
   `{{VAULT_PATH}}/projects/agent-distribution-lab/results.md`
   under "In-flight WSes" and to the project README "In-flight WSes" table.

CONSTRAINTS for this WS:

- The assigned profile is **immutable** once any task on this board moves
  to `running`. If the profile is wrong, flag it BEFORE the first dispatch.
- Every user intervention (clarification, correction, escalation reply)
  becomes a kanban comment on the relevant task. Don't bury feedback in
  chat — the ranker reads the board.
- Profile drift (you silently doing work that the profile assigns to a
  different agent) is a ranker demerit. If a profile rule needs bending,
  bend it explicitly in the `ws-log` `Profile drift incidents` section.
- **POC validation** (`poc-validation.md`): every card whose deliverable
  is running code that emits measurable output must be flagged `--poc`
  at create and paired with a validate card owned by a different squad
  agent. Owner card cannot `complete` until validate card lands PASS.
  Unvalidated POC closed as done → soundness cap at 3/5 for the WS.
  Fabrication caught by validator → soundness drops to 1/5.
- At WS-lock, fill the post-flight scorecard and append to results.md.

===PROMPT END===

---

## Operator notes (not part of the prompt)

- The `auto` profile choice in the prompt is the rule-driven path; the
  human override is "name P1/P2/P3 explicitly". Use the override when you
  have a specific hypothesis to test on the next WS.
- If you want to compare two Hephaestus backing models fairly, queue at
  least 2 P2 WSes: one before the
  `~/.hermes/profiles/hephaestus/config.yaml` model swap, one after. Tag
  via the `codex_available` flag.
- The prompt deliberately does NOT include the WS's substantive scope —
  that goes in the PFS or in the `Scope freeze` field. The prompt is
  pure bootstrap.
