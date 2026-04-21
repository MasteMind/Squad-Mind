# AGENTS.md — Hermes Setup Kit

*Agent-executable guide for bootstrapping the Hermes multi-agent system.*

---

## Role Definition

**You are the Setup Agent.** Your goal is to execute the Hermes Setup Kit on a fresh Linux or macOS machine and reach a green `smoke-test-report.json` with `overall: PASS`.

Read this file first, then execute stages in `bootstrap/` in order, respecting `hermes-setup.state`. Do not skip steps. Do not proceed past a failed verification block.

---

## Environment Expectations

- Target OS: Linux (Debian/Ubuntu/Fedora/Arch) or macOS (Darwin)
- Internet access required
- At least 1 GB free disk space in `$HOME`
- User has sudo OR accepts user-space install fallbacks
- At least one LLM provider:
  - **API keys** for Anthropic, Google, Kimi, OpenRouter, or Ollama local; OR
  - **CLI subscriptions** (Claude Max, Gemini Advanced) for proxy mode

---

## Provider Modes

The kit supports two ways to connect to LLMs:

| Mode | Requirements | Best For |
|------|-------------|----------|
| **API keys** | Provider API keys | Users with API credits, no CLI subscriptions |
| **CLI proxy** | `llm-cli-proxy` npm package + authenticated CLI | Users with Claude Max or Gemini Advanced subscriptions |

### Proxy Mode Quick Start

If the user chooses CLI proxy mode during interview:

1. Ensure `llm-cli-proxy` is installed: `npm install -g llm-cli-proxy`
2. Ensure CLIs are installed and authenticated:
   - Claude: `npm install -g @anthropic-ai/claude-code` then `claude login`
   - Gemini: `npm install -g @google/gemini-cli` then `gemini login`
3. After Stage 4 (`40-agents-wire.sh`), start proxies:
   ```bash
   ./scripts/start-proxies.sh
   ```
4. Proxies run in `screen` sessions. Verify: `screen -ls`

## Execution Order

1. Read `setup.md` for the human-facing narrative and context.
2. Read `INTERVIEW.md` — ask the user all questions and write answers to `setup_answers.yaml`.
3. Execute `bootstrap/00-prereqs.sh` through `bootstrap/50-smoke-test.sh` in numeric order.
4. **If proxy mode:** Run `./scripts/start-proxies.sh` after Stage 4.
5. After each stage, check `hermes-setup.state` to confirm the step advanced.
6. If a stage fails, stop. Do not proceed. Report the failure and await user input.

---

## Stage Scripts

| Stage | Script | Purpose |
|-------|--------|---------|
| 0 | `bootstrap/00-prereqs.sh` | OS detection, dependency checks, state file init |
| 1 | `bootstrap/10-obsidian.sh` | Download, verify, install Obsidian (or skip with `--headless`) |
| 2 | `bootstrap/20-hermes-core.sh` | Create `~/.hermes` skeleton |
| 3 | `bootstrap/30-vault-seed.sh` | Copy templates → vault, interpolate variables |
| 4 | `bootstrap/40-agents-wire.sh` | Enable chosen agents, write `.env`, set permissions |
| 5 | `bootstrap/50-smoke-test.sh` | Provider ping, vault integrity, permission audit |

---

## Verification Rules

Every stage script contains a **verification block** at the bottom. You must run it and confirm success before advancing. Common checks:

- `grep -r '\${' "$VAULT_PATH"` → must return zero matches after interpolation
- `ls -ld ~/.hermes` → must show `drwx------`
- `stat -c '%a' .env` → must show `600`
- Provider `models` endpoint (API-keys mode) → must return HTTP 200
- Proxy `/health` endpoint (proxy mode) → must return HTTP 200

---

## State File

`hermes-setup.state` tracks progress. Format:

```
STEP=3
LAST_RUN=2026-04-20T21:30:00Z
PLATFORM=Linux
```

If resuming after a crash, read `STEP` and start from the next stage. Do not re-run completed stages.

---

## If Something Goes Wrong

1. Check `bootstrap/log/<stage>.log` for detailed error output.
2. Consult `setup.md` Section "Troubleshooting".
3. Run `scripts/uninstall.sh` to cleanly reverse (preserves vault by default; use `--purge` to delete vault too).
4. Re-run from Step 0 — idempotency is guaranteed.

---

## Constraints

- Do not commit `.env`, `hermes-setup.state`, or user-generated vault content to git.
- Do not hardcode paths — use `$HERMES_HOME` and `$VAULT_PATH` from `setup_answers.yaml`.
- Do not proceed past failures. A half-installed system is worse than no installation.
