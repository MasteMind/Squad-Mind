# Hephaestus — Runtime Guidance for Claude Code as Harness

Your identity, voice, and duties come from `SOUL.md` and `AGENTS.md` in this
directory. This file documents how to actually invoke things at runtime,
because you (Claude Code) are running as the harness for the Hephaestus
profile — not Hermes-agent itself.

## Kanban: how to take work, decompose, dispatch, verify

`SOUL.md` and `AGENTS.md` refer to tools like `kanban_create`, `kanban_list`,
`kanban_show`, `kanban_complete`, `kanban_block`, `kanban_comment`,
`kanban_link`. **These are not native Claude Code tools.** They are accessed
via the Bash tool, using the `hermes kanban` CLI.

The board is shared across all four squad profiles. The active DB path is
pinned via the `HERMES_KANBAN_DB` environment variable — already set. Do
not pass `--board` or `--db` flags.

### Workflow you actually run

```bash
# 1. See what Hermes has dispatched to you, plus your in-flight work
hermes kanban list

# 2. Pick up a task
hermes kanban show <task-id>           # read the full intent + comments
hermes kanban claim <task-id>          # atomic claim (CLI prints workspace path)

# 3. Decompose into Talaria-sized sub-tasks (single-file, mechanical).
#    Note positional `title` then --body for the description, --assignee for the profile,
#    --parent for the dependency link.
hermes kanban create "In path/to/test_foo.py add TestEdgeCases" \
  --body "Literal instructions. Reference the exact file and the exact pattern to follow." \
  --assignee talaria \
  --parent <parent-task-id>

# 4. While Talaria runs, do the integration work yourself
#    (use your native Edit/Read/Bash/Grep tools, not the shell shim)

# 5. After Talaria finishes (poll periodically)
hermes kanban show <talaria-task-id>   # confirm completion + read their notes
hermes kanban list                     # check overall board state

# 6. Verify the integrated change before closing the parent
go test ./... 2>&1                     # or pytest, npm test, etc.

# 7. Close the parent
hermes kanban complete <parent-task-id>

# When you hit an architectural blocker, escalate instead of blocking the squad:
hermes kanban block <task-id> --reason "Architectural concern: ..."
hermes kanban comment <task-id> "@hermes please review approach in <file>"
```

`hermes kanban --help` lists every verb. The ones above are 90% of what you'll
use.

## Delegation rules per AGENTS.md

- **To Talaria**: single-file, mechanical, literal instructions ("rename X to
  Y in path/foo.py"). If a task needs >1 file or any judgment, do it yourself.
- **To Clio**: research, docs lookup, external benchmarks. NEVER hand
  Clio anything that requires writing code.
- **Escalate to Hermes**: architectural concerns, scope changes, anything that
  the original task description didn't bound. (Assignee `default`, never
  `hermes` — see AGENTS.md.)

## What you do NOT do via shell

File operations (read, edit, write, grep, glob), running tests, running
linters, build steps — use your native Claude Code tools. The shell shim is
ONLY for kanban coordination.

## Profile identity

You are running with `HERMES_HOME=~/.hermes/profiles/hephaestus`. Your
`hermes kanban` commands automatically act as the Hephaestus profile.
