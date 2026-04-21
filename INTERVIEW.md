# Hermes Setup Interview

*The setup agent reads this file and asks the user each question. Answers are recorded to `setup_answers.yaml`.*

---

## How to Use

1. Ask the user each question in order.
2. Accept defaults (shown in brackets) if the user presses Enter.
3. Write all answers to `setup_answers.yaml` in the schema shown at the bottom.
4. Validate: ensure `setup_answers.yaml` parses as valid YAML and all required keys are present.

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

### 2. Paths

**Q4. Where should the Home-Brain vault live?**  
Default: `~/Documents/Home-Brain`  
Maps to: `paths.vault`  
Note: Expanded to absolute path. Parent directory must exist or be creatable.

**Q5. Where should the Hermes runtime (`~/.hermes`) live?**  
Default: `~/.hermes`  
Maps to: `paths.hermes_home`  
Note: This is ephemeral app data, not the vault.

---

### 3. Provider Mode

**Q6. How do you want to connect to LLM providers?**  
Default: `api-keys`

| Option | Description | Requirements |
|--------|-------------|--------------|
| `api-keys` | Direct API calls to Anthropic, Google, etc. | API keys for each provider |
| `cli-proxy` | Route through Claude Code / Gemini CLI via local proxy | Claude Max or Gemini Advanced subscription; `llm-cli-proxy` npm package |

**Important:** `cli-proxy` mode lets you use your existing CLI subscriptions instead of paying for API credits. The proxy runs locally and translates OpenAI-compatible requests to the native CLI.

Maps to: `providers.mode`  
Used in: `.env`, `bootstrap/40-agents-wire.sh`, smoke test

---

### 4. Sub-agents

**Q7. Which agents do you want to enable?** (check all that apply)  
Default: `[orchestrator, coder]`

| Agent | Role | Default Provider | Purpose |
|-------|------|------------------|---------|
| ☐ orchestrator | Hermes | Claude Sonnet 4.6 | Central coordinator — **required** |
| ☐ coder | Hephaestus | Kimi-for-coding | Code generation, debugging |
| ☐ researcher | Clio | Gemini-2.5-pro | General research, academic papers |
| ☐ financial | Athena | Gemini-2.5-pro | Tax, budgeting, investments |
| ☐ health | Asclepius | Gemini-2.5-pro | Family health tracking |
| ☐ monitor | Argus | Minimax-M2.5-free | Infrastructure, cost tracking |
| ☐ reasoning | Solon | DeepSeek-R1 | Logic validation, architecture critique |
| ☐ local | Lab-Assistant | Ollama (local) | On-device private inference |

Maps to: `agents.enabled`  
Used in: `AGENT_ROSTER.md`, `.env`, delivery config

---

### 5. Providers

**Q8. Which LLM API keys do you have?** (check all that apply)  
*Only asked if provider mode is `api-keys`.*  
Default: (none)

| Provider | Key Env Var | Best For |
|----------|-------------|----------|
| ☐ Anthropic (Claude) | `ANTHROPIC_API_KEY` | Orchestrator, general reasoning |
| ☐ Google (Gemini) | `GOOGLE_API_KEY` | Research, financial, health agents |
| ☐ Kimi (Moonshot) | `KIMI_API_KEY` | Coder agent |
| ☐ OpenRouter | `OPENROUTER_API_KEY` | Reasoning mentor (DeepSeek-R1) |
| ☐ OpenAI | `OPENAI_API_KEY` | Optional fallback |
| ☐ Ollama (local) | `OLLAMA_BASE_URL` | On-device, no API key needed |

For each selected provider, securely prompt for the API key (do not echo to terminal).  
Maps to: `providers.*.api_key`  
Used in: `.env`

**Q8-alt. Which CLI subscriptions do you have?** (check all that apply)  
*Only asked if provider mode is `cli-proxy`.*  
Default: (none)

| Provider | CLI Command | Proxy Port | Best For |
|----------|-------------|------------|----------|
| ☐ Claude Max | `claude` | 3456 | Orchestrator, general reasoning |
| ☐ Gemini Advanced | `gemini` | 3457 | Research, financial, health agents |

*Note: Each additional Gemini agent gets its own port (3458, 3459, etc.) for isolation.*  
Maps to: `providers.cli_proxy.enabled`  
Used in: `.env`, proxy startup scripts

---

### 6. Delivery

**Q9. Which delivery platforms do you want?**  
Default: `local-only`

| Option | Description |
|--------|-------------|
| `local-only` | Agents write to vault files only |
| `telegram` | Telegram bots for each enabled agent |
| `slack` | Slack webhooks |
| `none` | No delivery configuration |

If Telegram: ask for bot token(s) and chat ID.  
Maps to: `delivery.platform`, `delivery.telegram.*`  
Used in: `~/.hermes/profiles/`, `.env`

---

### 7. Starter Projects

**Q10. Enable Health Management project?**  
Default: `yes`  
Maps to: `projects.health`  
Includes: member registry, insurance tracker, vaccination schedule, checkup log, medication inventory

**Q11. Enable Finance Management project?**  
Default: `yes`  
Maps to: `projects.finance`  
Includes: net worth tracker, monthly budget, investments, tax planning, insurance, action plan

---

### 8. Locale

**Q12. Currency symbol?** (e.g. `$`, `€`, `£`, `¥`)  
Default: `$`  
Maps to: `locale.currency_symbol`  
Used in: finance templates

**Q13. Country / tax regime?** (e.g. `US`, `UK`, `DE`, `Generic`)  
Default: `Generic`  
Maps to: `locale.country_code`  
Used in: tax-planning stub

**Q14. Household mode?**  
Default: `single`

| Option | Description |
|--------|-------------|
| `single` | One person using the vault |
| `family` | Multiple members tracked in health/finance projects |

Maps to: `locale.household_mode`  
Used in: health member registry template

---

### 9. Installation Mode

**Q15. Install Obsidian GUI? Or run headless (server)?**  
Default: `gui`

| Option | Description |
|--------|-------------|
| `gui` | Download and install Obsidian desktop app |
| `headless` | Skip Obsidian — vault is plain Markdown, no GUI |

Maps to: `install.mode`  
Note: Headless mode is recommended for servers, WSL, or CI.

---

### 10. Auto-Start

**Q16. How should agents start on boot?**  
Default: `manual`

| Option | Description |
|--------|-------------|
| `manual` | User starts agents manually |
| `systemd` | systemd user services (Linux) |
| `screen` | screen/tmux sessions |

Maps to: `install.auto_start`  
Used in: `~/.config/systemd/user/` or startup scripts

---

## Output Schema: `setup_answers.yaml`

```yaml
version: "1.0"
date: "2026-04-20"
user:
  name: "Alex"
  email: "alex@example.com"
  timezone: "America/New_York"
paths:
  vault: "/home/alex/Documents/Home-Brain"
  hermes_home: "/home/alex/.hermes"
providers:
  mode: "api-keys"          # or "cli-proxy"
  anthropic:
    api_key: "sk-ant-..."   # only in api-keys mode
  google:
    api_key: "AIza..."      # only in api-keys mode
  kimi:
    api_key: "..."          # only in api-keys mode
  cli_proxy:
    enabled:
      - claude               # only in cli-proxy mode
      - gemini               # only in cli-proxy mode
    ports:
      claude: 3456
      gemini: 3457
agents:
  enabled:
    - orchestrator
    - coder
  roster:
    orchestrator:
      name: "Hermes"
      provider: "anthropic"
      model: "claude-sonnet-4-6"
    coder:
      name: "Hephaestus"
      provider: "kimi"
      model: "kimi-for-coding"
delivery:
  platform: "local-only"
  telegram:
    bot_token: "..."
    chat_id: "..."
projects:
  health: true
  finance: true
locale:
  currency_symbol: "$"
  country_code: "US"
  household_mode: "single"
install:
  mode: "gui"
  auto_start: "manual"
```

---

## Validation Checklist

Before proceeding to bootstrap:

- [ ] `setup_answers.yaml` parses as valid YAML
- [ ] `user.name` is non-empty
- [ ] `paths.vault` is an absolute path
- [ ] `paths.hermes_home` is an absolute path
- [ ] `agents.enabled` contains at least `orchestrator`
- [ ] `providers.mode` is one of: `api-keys`, `cli-proxy`
- [ ] If `api-keys` mode: each enabled agent's required provider has a non-empty `api_key`
- [ ] If `cli-proxy` mode: `providers.cli_proxy.enabled` is non-empty
- [ ] `install.mode` is one of: `gui`, `headless`
