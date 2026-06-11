# Squad-Mind

A reproducible **team-of-thoughts**: bootstrap a 4-agent engineering squad with
a shared, git-backed team brain — on your laptop or on a team server.

## What it is

Squad-Mind installs and wires a squad of specialized AI agents that coordinate
through a durable kanban board and a shared Markdown vault:

| Agent | Role | What it does |
|---|---|---|
| **Hermes** | orchestrator | Talks to humans, decomposes work, enforces governance |
| **Hephaestus** | builder | Writes, tests, debugs, and refactors code |
| **Clio** | researcher | External surveys, doc navigation, evidence collection |
| **Talaria** | junior | Mechanical single-file edits, dispatched by the builder |

Around the squad:

- **Team-brain vault** — an Obsidian-compatible Markdown knowledge base the
  agents read and write; on servers it's a git repo with full history.
- **Kanban coordination** — SQLite-backed board; tenant-isolated working
  sessions; a dispatcher that claims and spawns agents.
- **Distribution-lab governance** — named agent-distribution profiles
  (P1/P2/P3), a scoring rubric, and a **POC-validation contract**: any card
  claiming measured numbers must be independently reproduced by a *different*
  agent before it can close. See
  [templates/vault/projects/agent-distribution-lab/](templates/vault/projects/agent-distribution-lab/README.md).

Per-agent model/CLI/port bindings are pinned in [models.lock.yaml](models.lock.yaml)
— the single source of truth every consumer reads.

## Two deployment modes

| | **Laptop** (single user) | **Team server** (shared) |
|---|---|---|
| Install | Interview + bootstrap stages | [deploy/server-install.sh](deploy/server-install.sh) |
| Providers | API keys **or** CLI-subscription proxies | **API keys only** (CLI subscriptions are per-human licenses — see the licensing box in [docs/server-deployment.md](docs/server-deployment.md)) |
| Surface | CLI / local gateway | Slack (mention-gated, Socket Mode) |
| Brain | Local vault | Git repo, auto-committed, humans edit via PR |
| Ops | manual / launchd / user systemd | system units, nightly backups, audit export |

### Quickstart — laptop

```bash
git clone --recurse-submodules <repo-url> squad-mind && cd squad-mind
# Run with any capable CLI agent (it reads AGENTS.md and interviews you), or by hand:
./bootstrap/00-prereqs.sh
./bootstrap/10-obsidian.sh        # or --headless
./bootstrap/20-hermes-core.sh
./bootstrap/30-vault-seed.sh
./bootstrap/40-agents-wire.sh
./bootstrap/50-smoke-test.sh
./bootstrap/60-delivery.sh
./bootstrap/70-autostart.sh
./bootstrap/80-lab-seed.sh
./bootstrap/90-first-run.sh
```

The interview ([INTERVIEW.md](INTERVIEW.md)) asks ~14 questions and generates
the whole system from your answers. CLI-proxy mode (Claude Max / Gemini
Advanced subscriptions) is fine here — it's your personal license on your
machine.

### Quickstart — team server

```bash
git clone --recurse-submodules <repo-url> && cd Squad-Mind
sudo deploy/server-install.sh --team-name "My Team" \
    --admin-name "Alex" --timezone "UTC" \
    --brain-git-url git@github.com:org/team-brain.git
sudo vim /srv/squad/secrets/.env      # API keys + Slack tokens
sudo systemctl start squad-mind.target
```

Full runbook (sizing, Slack app from
[deploy/slack/app-manifest.yml](deploy/slack/app-manifest.yml), verification,
backup/restore, troubleshooting): [docs/server-deployment.md](docs/server-deployment.md).

## Repo map

```
Squad-Mind/
├── AGENTS.md              # machine-readable execution guide for setup agents
├── setup.md               # human-readable laptop runbook
├── INTERVIEW.md           # scripted Q&A (answers schema v2)
├── models.lock.yaml       # pinned agent ↔ model bindings (single source of truth)
├── ONBOARDING.md          # team-facing: Slack usage, POC flow, reading the brain
├── bootstrap/             # laptop stage scripts (00–90)
├── deploy/                # server: installer, systemd units, Slack manifest, ops scripts
├── docs/                  # server-deployment.md, phase2-hardening.md
├── templates/
│   ├── vault/             # brain seed: agents, lab governance, project template
│   ├── runtime/           # bot configs, launchd/systemd unit templates
│   └── skills/run-poc/    # orchestrator playbook for chat-driven POC sessions
├── scripts/               # utilities (backup, restore, rotate-keys, health-check, …)
├── tests/                 # integration + crash-recovery tests
└── tools/                 # vendored submodules (llm-cli-proxy)
```

## For your team

- New teammate? Start with [ONBOARDING.md](ONBOARDING.md).
- Operating a server? [docs/server-deployment.md](docs/server-deployment.md),
  then [docs/phase2-hardening.md](docs/phase2-hardening.md) for what comes next
  (and what is deliberately not built).

## Security

- `.env` is `chmod 600` and git-ignored; server secrets live in
  `/srv/squad/secrets/.env` (`root:hermes 640`)
- CLI proxies bind to `127.0.0.1` only — and are dev/laptop mode only
- `scripts/rotate-keys.py` rotates credentials safely (laptop and server paths)
- Nightly backups + JSONL audit export on servers

## Testing

```bash
./tests/bootstrap-integration.sh    # full integration test in a clean container
./tests/crash-recovery.sh           # idempotency / resume-after-crash
```

## License

MIT — share with your team, your friend, your future self.
