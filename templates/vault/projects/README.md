# Projects — Mandatory Bootstrap Rule

Every project, initiative, or major workstream the squad touches MUST have a
home here BEFORE any substantive work happens on it — before drafting WS/RFC
docs, before deep architectural design, and **before the first kanban card is
dispatched**. Hermes owns this rule (see `agents/Hermes/CLAUDE.md` §"New
project bootstrap" and `agents/Hermes/AGENTS.md` §5); other agents route
new-project requests back to Hermes rather than bootstrapping themselves.

## Layout

```
projects/
├── <project-slug>/        # one directory per live project
│   ├── README.md          # REQUIRED — the durable pointer (fields below)
│   ├── WS.md              # REQUIRED when the project is active — working-session doc
│   ├── decisions.md       # ADR-style log; append-only once a decision is locked
│   └── notes/             # raw scratch, meeting notes, research snippets
├── _template/             # copy this to start a new project
└── _archived/             # closed runs, moved here as <slug>_<YYYY-MM-DD>/
```

`<project-slug>` is lowercase-kebab-case, matching the source spec title when
one exists.

## README.md required fields

Every `projects/<slug>/README.md` must carry, at minimum:

- **Status:** `discovery | scoping | active | paused | shipped | abandoned`
- **Owner:** who is accountable (usually Hermes)
- **Started:** YYYY-MM-DD
- **KR cycle:** the planning cycle this rolls up to
- **Pillar:** the initiative pillar / parent workstream
- **Source docs:** links/paths to the spec, related docs, and parent initiative

## Rules

1. **Bootstrap before kanban dispatch.** The README lands in the same session
   the project is kicked off — never "later".
2. **WS.md exists while active.** It is the primary working-session document;
   Hermes authors it as decomposition proceeds.
3. **decisions.md is append-only once locked.** Date + decision + rationale,
   recorded as they happen — don't backfill from memory.
4. **notes/ is scratch.** Research outputs, spike writeups, and copied source
   docs live here so cited paths stay durable.
5. **Archive closed runs.** When a project finishes (or is abandoned), move
   its directory to `_archived/<slug>_<YYYY-MM-DD>/`.
6. **Status moves with reality.** Paused work gets `Status: paused` plus a
   one-line reason in the README body.
