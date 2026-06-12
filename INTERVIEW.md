# Hermes Setup Interview (v2)

*The setup agent reads this file and asks the user each question. Answers are recorded to `setup_answers.yaml` (schema `version: "2.0"`).*

> **Schema 2.0 is required.** Version 1.0 answer files are **rejected** by every bootstrap stage — if you have an old `setup_answers.yaml`, rerun this interview (or `scripts/reverse-interview.py`) to regenerate it.

---

## How to Use

1. Ask the user each question in order.
2. Accept defaults (shown in brackets) if the user presses Enter.
3. Per-agent defaults (CLI / model / port) come from `models.lock.yaml` — the single source of truth. Print them when asking Q9.
4. Write all answers to `setup_answers.yaml` in the schema shown at the bottom.
5. Validate: ensure `setup_answers.yaml` parses as valid YAML and all required keys are present.

---

## Questions

### 1. Identity

**Q1. What is your name?**
Default: `User`
Maps to: `user.name`
Used in: `brain/Memories.md`, `brain/hot.md`

**Q2. Primary email?**
Default: (none — optional)
Maps to: `user.email`
Used in: `brain/Memories.md`

**Q3. Timezone?** (IANA format, e.g. `America/New_York`, `Europe/London`, `Asia/Tokyo`)
Default: `UTC`
Maps to: `user.timezone`
Used in: cron schedules, daily note timestamps

---

### 2. Team

**Q4. What is your team called?**
Default: `My Team`
Maps to: `team.name`
Used in: agent personas (`agents/*/SOUL.md`, `agents/*/AGENTS.md`), `brain/Memories.md`

*Optional follow-up:* a one-paragraph description of the team's domain, systems, and architecture. Maps to `team.domain_blurb`. If skipped, the seeded vault carries a `<!-- TODO: ... -->` marker for the team to fill in later.

---

### 3. Paths

**Q5. Where should the team-brain vault live?**
Default: `~/Documents/Home-Brain`
Maps to: `paths.vault`
Note: Expanded to absolute path. Parent directory must exist or be creatable.

**Q6. Where should the Hermes runtime (`~/.hermes`) live?**
Default: `~/.hermes`
Maps to: `paths.hermes_home`
Note: This is ephemeral app data, not the vault.

---

### 4. Provider Mode

**Q7. How do you want to connect to LLM providers?**
Default: `cli-proxy`

| Option | Description | Requirements |
|--------|-------------|--------------|
| `api-keys` | Direct API calls to Anthropic, Google, OpenAI | API keys for each provider |
| `cli-proxy` | Route through Claude Code / Codex / Gemini CLIs via local proxies | CLI subscriptions; `llm-cli-proxy` |
| `mixed` | Some agents via proxy, some via direct API keys | Both of the above, per agent |

If `api-keys` or `mixed`: securely prompt for `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY` as needed (do not echo to terminal).
Maps to: `providers.mode`, `providers.{anthropic,google,openai}.api_key`
Used in: `.env`, `bootstrap/40-agents-wire.sh`, smoke test

---

### 5. Delivery

**Q8. Which delivery platform do you want?**
Default: `local-only`

| Option | Description |
|--------|-------------|
| `local-only` | Agents write to vault files only |
| `telegram` | One Telegram bot per agent (hermes, hephaestus, clio, talaria) |
| `slack` | Slack webhooks |
| `none` | No delivery configuration |

If Telegram: ask for per-agent bot tokens and the chat ID.
Maps to: `delivery.platform`, `delivery.telegram.bot_tokens.<agent>`, `delivery.telegram.chat_id`
Used in: `~/.hermes/profiles/`, `.env` (`TELEGRAM_BOT_TOKEN_{HERMES,HEPHAESTUS,CLIO,TALARIA}`)

---

### 6. Agent Roster

**Q9. Per-agent CLI / model / port overrides?**
Defaults (print these from `models.lock.yaml` — do not hardcode):

| Agent | Role | CLI | Model | Port |
|-------|------|-----|-------|------|
| hermes | orchestrator | `agents.hermes.cli` | `agents.hermes.model` | `agents.hermes.port` |
| hephaestus | builder | `agents.hephaestus.cli` | `agents.hephaestus.model` | `agents.hephaestus.port` |
| clio | researcher | `agents.clio.cli` | `agents.clio.model` | `agents.clio.port` |
| talaria | junior | (ollama runtime) | `agents.talaria.model` | — (no proxy) |

Most users accept all defaults. Record only the overrides.
Maps to: `agents.roster.<agent>.{cli,model,port}`
Used in: bot YAML rendering, `AGENT_ROSTER.md`, proxy units, smoke test

**Q10. Enable Talaria (the Ollama-backed junior agent)?**
Default: `yes` — if the user can provide an Ollama endpoint.
Ask for the Ollama base URL (default from `models.lock.yaml` `ollama.base_url`, normally `http://localhost:11434`). **Skippable:** if the user has no Ollama, record `agents.talaria_enabled: false` and omit `ollama.base_url` — the squad runs with 3 agents.
Maps to: `agents.talaria_enabled`, `ollama.base_url`

---

### 7. Lab

**Q11. Seed the agent-distribution-lab project?**
Default: `yes`
The lab is the squad's self-improvement machinery: distribution profiles, ranker rubric, POC validation contract, WS bootstrap prompt.
Maps to: `projects.lab`

**Q12. Default lab distribution profile?**
Default: `auto`

| Option | Description |
|--------|-------------|
| `P1` / `P2` / `P3` | Always use this profile (see `projects/agent-distribution-lab/profiles.md`) |
| `auto` | Orchestrator picks per working session |

Maps to: `lab.default_profile`

---

### 8. Installation Mode

**Q13. Install Obsidian GUI? Or run headless (server)?**
Default: `gui`

| Option | Description |
|--------|-------------|
| `gui` | Download and install Obsidian desktop app |
| `headless` | Skip Obsidian — vault is plain Markdown, no GUI |

Maps to: `install.mode`
Note: Headless mode is recommended for servers, WSL, or CI.

---

### 9. Auto-Start

**Q14. How should agents start on boot?**
Default: `manual` (but `launchd` is the recommended default on macOS)

| Option | Description |
|--------|-------------|
| `manual` | User starts agents manually |
| `launchd` | launchd user agents (macOS — proxies + gateways, rendered from `templates/runtime/launchd/`) |
| `systemd` | systemd user services (Linux — `proxy@` / `hermes-gateway@` templated units) |
| `screen` | screen/tmux sessions (fallback) |

Maps to: `install.auto_start`
Used in: `~/Library/LaunchAgents/` or `~/.config/systemd/user/` or startup scripts

---

## Output Schema: `setup_answers.yaml`

```yaml
version: "2.0"
date: "2026-06-11"
user:
  name: "Alex"
  email: "alex@example.com"
  timezone: "America/New_York"
team:
  name: "Checkout Platform"
  domain_blurb: "We own the checkout and payments flow..."   # optional
paths:
  vault: "/home/alex/Documents/Home-Brain"
  hermes_home: "/home/alex/.hermes"
providers:
  mode: "cli-proxy"            # api-keys | cli-proxy | mixed
  anthropic:
    api_key: "sk-ant-..."      # api-keys / mixed mode only
  google:
    api_key: "AIza..."         # api-keys / mixed mode only
  openai:
    api_key: "sk-..."          # api-keys / mixed mode only
agents:
  roster:                       # only overrides; defaults from models.lock.yaml
    hermes:
      model: "claude-opus-4-7"
      port: 3456
    hephaestus:
      cli: "codex"
      model: "gpt-5.5"
      port: 3458
    clio:
      model: "gemini-2.5-flash"
      port: 3457
    talaria:
      model: "qwen3.5:9b-q4_K_M"
  talaria_enabled: true
ollama:
  base_url: "http://localhost:11434"   # omit if talaria_enabled is false
lab:
  default_profile: "auto"      # P1 | P2 | P3 | auto
projects:
  lab: true
delivery:
  platform: "local-only"
  telegram:                    # only when platform: telegram
    bot_tokens:
      hermes: "..."
      hephaestus: "..."
      clio: "..."
      talaria: "..."
    chat_id: "..."
install:
  mode: "gui"                  # gui | headless
  auto_start: "manual"         # manual | launchd | systemd | screen
```

---

## Validation Checklist

Before proceeding to bootstrap:

- [ ] `setup_answers.yaml` parses as valid YAML
- [ ] `version` is `"2.0"` (version 1.0 files are rejected — rerun the interview)
- [ ] `user.name` is non-empty
- [ ] `team.name` is non-empty
- [ ] `paths.vault` is an absolute path
- [ ] `paths.hermes_home` is an absolute path
- [ ] `providers.mode` is one of: `api-keys`, `cli-proxy`, `mixed`
- [ ] If `api-keys` mode: each non-Ollama agent's provider has a non-empty `api_key`
- [ ] If `agents.talaria_enabled` is true (or omitted with an answer given): `ollama.base_url` is set
- [ ] Any `agents.roster.*.port` overrides are distinct localhost ports
- [ ] `lab.default_profile` is one of: `P1`, `P2`, `P3`, `auto`
- [ ] `install.mode` is one of: `gui`, `headless`
- [ ] `install.auto_start` is one of: `manual`, `launchd`, `systemd`, `screen`
