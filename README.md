# Squad-Mind

A shareable, agent-executable bootstrap kit for building end-to-end AI agent teams with a shared knowledge brain.

## What is Squad-Mind?

Squad-Mind helps you spin up a **team of specialized AI agents** — each with their own role, model, and purpose — all connected to a shared **Home-Brain vault** (an Obsidian-compatible Markdown knowledge base).

Originally built for the Hermes multi-agent system, Squad-Mind is fully generalized: use it for personal productivity, professional workflows, or any project where a team of AI agents needs structured memory and coordination.

## Who is this for?

- **Developers** who want their own private, extensible AI agent system
- **Teams** who need structured agent workflows with shared knowledge
- **Builders** who want to prototype multi-agent setups without boilerplate
- **Individuals** who want to automate their life — health tracking, financial planning, learning, and daily productivity — with agents that actually remember context
- Anyone with at least one LLM API key (or CLI subscription) who believes AI works better in teams

## Personal Use: Your Life, Automated

Squad-Mind isn't just for engineering teams. It's how we personally manage:

- **Health** — track checkups, medications, vaccinations, and insurance across family members
- **Finance** — net worth, monthly budgets, investments, tax planning, and action items
- **Knowledge** — a Home-Brain vault that agents read and write to, so nothing is lost between sessions
- **Daily priorities** — agents start every session knowing what's top of mind

Your agents become teammates for life, not just work.

## Quick Start

### Option A: Native Installation (default)

```bash
git clone https://github.com/MasteMind/Squad-Mind.git
cd Squad-Mind
# Run with any capable CLI agent (Claude Code, Kimi, Codex, etc.)
# Or run the bootstrap scripts manually:
./bootstrap/00-prereqs.sh
./bootstrap/10-obsidian.sh
./bootstrap/20-hermes-core.sh
./bootstrap/30-vault-seed.sh
./bootstrap/40-agents-wire.sh
./bootstrap/50-smoke-test.sh
./bootstrap/60-delivery.sh
./bootstrap/70-autostart.sh
./bootstrap/80-starter-projects.sh
./bootstrap/90-first-run.sh
```

### Option B: Docker Fast-Path (isolated, zero-config)

```bash
docker-compose -f docker-compose.bootstrap.yml up
```

## What Gets Installed

1. **Obsidian** (optional — skipped with `--headless` for servers)
2. **Home-Brain vault** — structured Markdown knowledge base at your chosen path
3. **Agent runtime** (`~/.hermes`) — agent profiles, bot configs, scripts, backups
4. **Sub-agents** — wired to your chosen LLM providers (API keys or CLI proxies)
5. **Starter projects** — Health Management and Finance Management templates
6. **Auto-start** — systemd user units or screen wrappers (optional)

## Provider Modes

| Mode | Best For |
|------|---------|
| **API Keys** | Users with API credits, no CLI subscriptions |
| **CLI Proxy** | Users with Claude Max or Gemini Advanced subscriptions |
| **Mixed** | One agent via proxy, another via API key — whatever works for you |

The kit writes all configured credentials to `.env` and each agent uses the connection you choose.

## Minimum Requirements

- Linux or macOS
- Internet connection
- 1 GB free disk space
- At least one LLM provider:
  - API key (Anthropic, Google, Kimi, OpenRouter, OpenAI, Ollama), OR
  - CLI subscription (Claude Max, Gemini Advanced)

## Interview-Driven Setup

The kit asks you ~15 questions up front (name, timezone, which agents to enable, API keys, etc.) and generates a personalized system from your answers. No personal data is hardcoded — everything is interpolated from your responses.

## Project Structure

```
Squad-Mind/
├── AGENTS.md              # "README for agents" — machine-readable execution guide
├── setup.md               # Human-readable runbook
├── INTERVIEW.md           # Scripted Q&A for setup personalization
├── bootstrap/             # Stage scripts (00-90)
├── templates/             # Vault + runtime skeletons + systemd units
├── scripts/               # Utilities (uninstall, rotate-keys, reverse-interview, backup, health-check)
├── tests/                 # Integration & crash-recovery tests
├── .github/workflows/     # CI (Docker-based integration tests + ShellCheck)
└── docker-compose.bootstrap.yml  # Optional Docker fast-path
```

## Security

- `.env` is created with `chmod 600` and auto-added to `.gitignore`
- API keys are never committed
- `~/.hermes` is created with `drwx------` permissions
- CLI proxies bind to `127.0.0.1` only (never `0.0.0.0`)
- Use `scripts/rotate-keys.py` to safely rotate credentials
- Use `scripts/backup-vault.sh` before destructive operations

## Utilities

```bash
./scripts/backup-vault.sh           # Backup vault to ~/.hermes/backups/
./scripts/restore-vault.sh          # Restore from a backup
./scripts/health-check.sh           # Verify entire stack is healthy
./scripts/rotate-keys.py            # Rotate API keys safely
./scripts/reverse-interview.py      # Regenerate interview from current vault
./scripts/uninstall.sh              # Remove runtime, preserve vault
./scripts/uninstall.sh --purge      # Remove runtime + vault
```

## Testing

```bash
# Full integration test in a clean Debian container
./tests/bootstrap-integration.sh

# Crash-recovery / idempotency test
./tests/crash-recovery.sh
```

## License

MIT — share with your team, your friend, your future self.
