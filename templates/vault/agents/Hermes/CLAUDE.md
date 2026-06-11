# Hermes — Runtime Guidance for Claude Code as Harness

Your identity, voice, and duties come from `SOUL.md` and `AGENTS.md` in this
directory. This file documents how to actually invoke things at runtime,
because you (Claude Code) are running as the harness for the Hermes profile —
not Hermes-agent itself.

## Kanban: how to dispatch and coordinate

`SOUL.md` and `AGENTS.md` refer to tools like `kanban_create`, `kanban_list`,
`kanban_comment`, `kanban_complete`, `kanban_block`. **These are not native
Claude Code tools.** They are accessed via the Bash tool, using the
`hermes kanban` CLI.

The board is shared across all four squad profiles (Hermes / Hephaestus /
Clio / Talaria). The active DB path is pinned via the `HERMES_KANBAN_DB`
environment variable — already set in your environment. Do not pass
`--board` or `--db` flags.

Common verbs (run `hermes kanban --help` for the full list):

```bash
# See current state of the board
hermes kanban list

# Assign work to another squad member.
# --assignee accepts:
#   - hephaestus, clio, talaria  (named profiles under ~/.hermes/profiles/)
#   - default                    (the root ~/.hermes profile == YOU, Hermes)
# NEVER use --assignee hermes. 'hermes' is in the codebase's reserved-name
# set (hermes_cli/profiles.py:_RESERVED_NAMES) — no profile dir can exist
# at ~/.hermes/profiles/hermes/, so the kanban dispatcher's
# profile_exists() pre-check silently routes such tasks to
# skipped_nonspawnable and they stay ready forever with no events, no
# failure counter, no log line. The canonical Hermes assignee at the CLI
# level is `default`.
# Note positional `title`, then --body for the description.
hermes kanban create "Decompose the service refactor" \
  --body "Break the pipeline rebuild into epics. Reference: <link to the relevant design doc>" \
  --assignee hephaestus

# Same pattern when YOU (Hermes) are the owner of a kanban task:
hermes kanban create "Drive WS doc to team-aligned lock" \
  --body "Orchestration card. Pulls outputs back from Clio/Hephaestus children." \
  --assignee default

# Add commentary on an in-flight task
hermes kanban comment <task-id> "Architectural blocker: <one line> — escalating"

# Mark your own task done
hermes kanban complete <task-id>

# Read a task in full
hermes kanban show <task-id>
```

When you create a task, capture the task ID from the CLI output and surface
it back to the user so they can track progress.

## What you do NOT do via shell

File operations (read, edit, write, grep, glob), running tests, navigating
the filesystem — use your native Claude Code tools (Read, Edit, Bash for
shell commands, Glob, Grep). Only kanban-style coordination needs the shell
shim.

## Squad routing rules

Per the squad design (see SOUL.md, AGENTS.md):

- **Architecture / design / runbook standards** — keep with yourself (Hermes,
  assignee=`default`).
- **Implementation / multi-file integration** — dispatch to **hephaestus**.
- **Research / docs navigation / external technology survey** — dispatch
  to **clio**.
- **Single-file mechanical edits / renames / unit-test additions** — these
  are Hephaestus's call to make to **talaria**, not yours directly. Route
  through Hephaestus.

### Hermes-owned kanban tasks: assignee MUST be `default`, not `hermes`

When a task belongs to you (the Hermes architect role), assign it to
`default` — that is the dispatcher-visible name of the root `~/.hermes`
profile. `hermes` is in `_RESERVED_NAMES` (hermes-agent source:
`hermes_cli/profiles.py`), so `profile_exists('hermes')` always returns
False, and the dispatcher's anti-crashloop guard
(`kanban_db.py:dispatch_once` → `skipped_nonspawnable`) silently bypasses
the task on every tick. Symptom: task sits in `ready` indefinitely with
`consecutive_failures=0`, no events past `created`, and no log entries —
you only find out via the staleness diagnostic (~30 min threshold).

## Profile identity

You are running with `HERMES_HOME=~/.hermes` (the default profile). When you
shell out, `hermes kanban` commands act as the Hermes profile by default. If
you need to act-as another profile (rare), prefix with
`hermes -p <name> kanban ...`.

At the dispatcher / `-p` flag level the Hermes profile is named **`default`**,
NOT `hermes` (see Kanban section above for the full rationale and the
crashloop-guard interaction).

## New project bootstrap (MANDATORY)

Whenever the user kicks off a new project, initiative, or workstream — phrases
like "let's start work on...", "new project:", "kick off X", "let's tackle Y"
— you MUST create the project's vault entry BEFORE you do substantive
work (drafting WS, dispatching kanban, deep architectural design).

Location and layout: see `AGENTS.md` §5 ("Project Tracking in the Vault").
Minimum on creation:

```bash
mkdir -p {{VAULT_PATH}}/projects/<slug>/notes
# then Write README.md with Status/Owner/Started/KR cycle/Pillar/source docs
```

The slug is lowercase-kebab-case derived from the project name (or spec title
when one exists). If a spec is attached, link it from the README's "Source
docs" section.

Do not silently skip this step "because the WS doc already exists" — the
README is the durable pointer; the WS is one of several artifacts under it.
