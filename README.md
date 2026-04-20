# Squad-Mind

A shareable, agent-executable bootstrap kit for building end-to-end AI agent teams with a shared knowledge brain.

## What is Squad-Mind?

Squad-Mind helps you spin up a **team of specialized AI agents** — each with their own role, model, and purpose — all connected to a shared **Home-Brain vault** (an Obsidian-compatible Markdown knowledge base).

Originally built for the Hermes multi-agent system, Squad-Mind is fully generalized: use it for personal productivity, professional workflows, or any project where a team of AI agents needs structured memory and coordination.

## Who is this for?

- **Developers** who want their own private, extensible AI agent system
- **Teams** who need structured agent workflows with shared knowledge
- **Builders** who want to prototype multi-agent setups without boilerplate
- Anyone with at least one LLM API key who believes AI works better in teams

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
```

### Option B: Docker Fast-Path (isolated, zero-config)

```bash
docker-compose -f docker-compose.bootstrap.yml up
```

## What Gets Installed

1. **Obsidian** (optional — skipped with `--headless` for servers)
2. **Home-Brain vault** — structured Markdown knowledge base at your chosen path
3. **Agent runtime** (`~/.hermes`) — agent profiles, bot configs, scripts
4. **Sub-agents** — wired to your chosen LLM providers
5. **Starter projects** — Health Management and Finance Management templates

## Minimum Requirements

- Linux or macOS
- Internet connection
- 1 GB free disk space
- At least one LLM API key

## Interview-Driven Setup

The kit asks you ~15 questions up front (name, timezone, which agents to enable, API keys, etc.) and generates a personalized system from your answers. No personal data is hardcoded — everything is interpolated from your responses.

## Project Structure

```
Squad-Mind/
├── AGENTS.md              # "README for agents" — machine-readable execution guide
├── setup.md               # Human-readable runbook
├── INTERVIEW.md           # Scripted Q&A for setup personalization
├── bootstrap/             # Stage scripts (00-50)
├── templates/             # Vault + runtime skeletons
├── scripts/               # Utilities (uninstall, rotate-keys, reverse-interview)
└── docker-compose.bootstrap.yml  # Optional Docker fast-path
```

## Security

- `.env` is created with `chmod 600` and auto-added to `.gitignore`
- API keys are never committed
- `~/.hermes` is created with `drwx------` permissions
- Use `scripts/rotate-keys.py` to safely rotate credentials

## Uninstall

```bash
./scripts/uninstall.sh        # Removes runtime, preserves vault
./scripts/uninstall.sh --purge  # Removes runtime + vault
```

## License

MIT — share with your team, your friend, your future self.
