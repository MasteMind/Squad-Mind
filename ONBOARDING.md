# Squad-Mind — Team Onboarding

You have a 4-agent AI squad running on a shared server, reachable from Slack.
This page is everything a teammate needs to use it. (Admins: the runbook is
[docs/server-deployment.md](docs/server-deployment.md).)

## What you get

- **Hermes** — orchestrator/architect. Talks to you, decomposes work, enforces
  the governance rules.
- **Hephaestus** — builder. Writes, tests, and debugs code.
- **Clio** — researcher. Surveys docs, vendors, and external evidence.
- **Talaria** — junior. Mechanical single-file edits, dispatched by the builder.

They coordinate through a shared kanban board and read/write a shared
**team brain** — a git-backed Markdown vault that survives every session. Work
runs under the [agent-distribution-lab](templates/vault/projects/agent-distribution-lab/README.md)
governance project: named distribution profiles, a scoring rubric, and an
anti-hallucination validation contract for anything that claims measured numbers.

## The Slack surface

- The squad lives in your team's squad channel (e.g. `#squad-<team>`), plus DMs.
- It is **mention-gated**: `@squad ...` starts it; plain channel chatter is ignored.
- **One thread = one working session.** Keep follow-ups in the thread; the
  squad keeps that thread's context together. New topic → new top-level mention.
- `/hermes <subcommand>` is available for direct commands.

## Asking for a POC

The flagship flow. Mention the squad with what you want evaluated:

> `@squad poc "evaluate scylla vs bigtable for seller-events dedup"`

What happens (full playbook: [templates/skills/run-poc/SKILL.md](templates/skills/run-poc/SKILL.md)):

1. Hermes confirms the scope and picks a distribution profile.
2. It bootstraps a project home in the brain, then dispatches isolated kanban
   cards across the squad.
3. Every card that produces measured output gets a **validate card owned by a
   different agent** — numbers must be independently reproduced before the work
   can close. No validator PASS, no done.
4. You get a summary and a permalink to the project's brain page back in your
   thread; the workspace is archived afterwards.

Expect to be asked one clarifying question if your scope is ambiguous. Tighter
ask, faster session.

## Reading (and editing) the brain

- The brain is a git repo. **Read it on GitHub** — projects under `projects/`,
  decisions in each project's `decisions.md`.
- **Agents auto-commit** their changes every few minutes. **Humans edit via
  PR** — never push directly to the brain's main branch; the agents rebase on
  top of it continuously and your direct push is how merge conflicts happen.
- Prefer Obsidian? Clone the brain locally as a **read-only** vault (pull-only;
  the obsidian-git plugin in pull-only mode works well).

## Roles, honestly

- The real gate is `SLACK_ALLOWED_USERS`: if your Slack user ID is on the
  server's allowlist, the squad answers you. If not, it ignores you. **The
  security boundary is channel membership plus that allowlist** — nothing finer.
- There is no finer-grained dispatch-vs-observe split: anyone the squad
  answers can dispatch work. Treat dispatch etiquette as a team social
  contract, and keep the allowlist tight.

## Where audit lives

- `brain/audit/YYYY-MM-DD.jsonl` — nightly export of every kanban event,
  comment, and run. Committed to the brain repo, so it's reviewable in git.
- The live kanban database (`task_events` table) holds the same trail in real
  time — admins can query it on the server.
- Every working session also leaves a scorecard in the lab's `ws-log/`.

## Who to call

- **Squad admins** have SSH to the server — service restarts, key rotation,
  allowlist changes, restores. Ask them in the squad channel.
- **Everyone else uses Slack.** If the squad stops responding, that's an admin
  ping, not a reason to go looking for server access.
