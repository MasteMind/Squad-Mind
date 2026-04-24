# Hermes Setup Kit — Master Runbook

*Agent-executable bootstrap for the Hermes multi-agent system. Read `AGENTS.md` first if you are a CLI agent.*

---

## Table of Contents

1. [Overview](#1-overview)
2. [Before You Start](#2-before-you-start)
3. [Step-by-Step Runbook](#3-step-by-step-runbook)
4. [Troubleshooting](#4-troubleshooting)
5. [Post-Install](#5-post-install)

---

## 1. Overview

This runbook bootstraps a complete Hermes multi-agent system from a fresh Linux or macOS machine. By the end, you will have:

- A structured **Home-Brain vault** (Obsidian-compatible Markdown)
- A **Hermes runtime** (`~/.hermes`) with agent profiles and delivery configs
- **Sub-agents** wired to your chosen LLM providers
- **Starter projects** for Health and Finance management
- A passing **smoke test** proving the chain works

**Time estimate:** 10–20 minutes, mostly automated.

---

## 2. Before You Start

### Prerequisites

- Linux (Debian/Ubuntu/Fedora/Arch) or macOS
- Internet connection
- 1 GB free disk space
- At least one LLM provider:
  - **API keys** for Anthropic, Google, Kimi, OpenRouter, or Ollama; OR
  - **CLI subscriptions** (Claude Max, Gemini Advanced) for proxy mode
- `curl`, `bash`, and standard POSIX utilities
- Node.js + npm (only for CLI proxy mode)

### What You Need to Know

- Your timezone (IANA format, e.g. `America/New_York`)
- Which agents you want (minimum: orchestrator + coder)
- Which LLM providers you have API keys for (or CLI subscriptions for proxy mode)
- Whether you want Telegram delivery or local-only

### Quick Start (One-Liner)

If you trust the agent:

```bash
git clone <repo> hermes-setup && cd hermes-setup && ./scripts/install.sh
```

Or run stage by stage (recommended for first time):

```bash
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

---

## 3. Step-by-Step Runbook

### Step 0 — Prerequisites & Environment Check

**Purpose:** Verify the machine can support Hermes. Detect OS, check disk space, probe sudo, initialize state.

**User Input:** None.

**What Happens:**
1. Detect OS via `uname` (Linux/macOS/WSL)
2. Check internet: `curl -I https://github.com` must return 200
3. Check disk: `df -h $HOME` must show >1 GB free
4. Probe sudo: test if `sudo -n true` succeeds
5. Check for existing Hermes installation (warn if found)
6. Initialize `hermes-setup.state` at `STEP=0`

**Artifacts:** `hermes-setup.state`, `bootstrap/log/prereqs.log`

**Verification:**
```bash
grep "STEP=0" hermes-setup.state
curl -I -s https://github.com | head -1 | grep "200"
```

---

### Step 1 — Interview the User

**Purpose:** Collect personalization data and choices.

**User Input:** All questions from `INTERVIEW.md`.

**What Happens:**
1. Ask the 15 questions in `INTERVIEW.md`
2. Write answers to `setup_answers.yaml`
3. Back up any previous `setup_answers.yaml` to `setup_answers.yaml.bak.<timestamp>`

**Artifacts:** `setup_answers.yaml`

**Verification:**
```bash
python3 -c "import yaml; yaml.safe_load(open('setup_answers.yaml'))"
grep -q "user:" setup_answers.yaml
grep -q "agents:" setup_answers.yaml
```

---

### Step 2 — Install Obsidian (or Skip)

**Purpose:** Download and install Obsidian at the pinned version, or skip if `--headless`.

**User Input:** `--headless` flag (optional); vault path from interview.

**What Happens:**
1. Read `install.mode` from `setup_answers.yaml`
2. If `headless`: log "Skipping Obsidian install (headless mode)" and advance
3. If `gui`:
   - Download Obsidian `.deb` (Linux) or `.dmg` (macOS) from pinned URL
   - Verify SHA256 checksum against `bootstrap/lib/checksums.txt`
   - Linux: use `debconf-set-selections` to pre-answer prompts, then `dpkg -i`
   - macOS: mount `.dmg`, copy `.app` to `/Applications`, remove quarantine attribute
4. Update `hermes-setup.state` → `STEP=2`

**Artifacts:** Obsidian binary; `hermes-setup.state`

**Verification:**
```bash
# Linux
which obsidian || dpkg -l obsidian | grep -q "^ii"
# macOS
ls /Applications/Obsidian.app/Contents/MacOS/Obsidian
# Either: checksum matches
sha256sum -c bootstrap/lib/checksums.txt | grep obsidian
```

---

### Step 3 — Install Hermes Agent Runtime (`~/.hermes`)

**Purpose:** Create the runtime skeleton from `templates/runtime/hermes/`.

**User Input:** `$HERMES_HOME` path (default `~/.hermes`).

**What Happens:**
1. Read `paths.hermes_home` from `setup_answers.yaml`
2. Create directory tree: `bots/`, `profiles/`, `bin/`, `scripts/`
3. Set permissions: `chmod 700 $HERMES_HOME`
4. Update `hermes-setup.state` → `STEP=3`

**Artifacts:** `~/.hermes/` with `drwx------`

**Verification:**
```bash
ls -ld ~/.hermes | awk '{print $1}' | grep "drwx------"
```

---

### Step 4 — Seed Vault from Templates

**Purpose:** Copy `templates/vault/` → `$VAULT_PATH`, interpolate variables.

**User Input:** All interview answers used as template variables.

**What Happens:**
1. Read `paths.vault` from `setup_answers.yaml`
2. Copy `templates/vault/` recursively to `$VAULT_PATH`
3. Interpolate variables: `${USER_NAME}`, `${USER_EMAIL}`, `${TIMEZONE}`, `${CURRENCY_SYMBOL}`, `${COUNTRY_CODE}`, `${HOUSEHOLD_MODE}`
4. Update `hermes-setup.state` → `STEP=4`

**Artifacts:** Fully populated vault.

**Verification:**
```bash
# No raw placeholders remaining
grep -r '\${' "$VAULT_PATH" || echo "PASS: No un-interpolated variables"
# Core files exist
test -f "$VAULT_PATH/brain/hot.md"
test -f "$VAULT_PATH/brain/Memories.md"
```

---

### Step 5 — Choose & Wire Sub-Agents + Providers

**Purpose:** Enable only the agents the user chose; write `.env` with provider configuration.

**User Input:** Which agents to enable; provider mode and credentials (already collected in interview).

**What Happens:**
1. Read `agents.enabled` and `providers` from `setup_answers.yaml`
2. Create `.env` from `.env.example`
   - **API-keys mode:** fill in actual API keys
   - **CLI-proxy mode:** configure `PROXY_MODE=true` and proxy URLs/ports
   - **Mixed mode:** write BOTH API keys AND proxy URLs if both are configured
3. Set `.env` permissions: `chmod 600 .env`
4. Auto-add `.env` to `.gitignore` if not present
5. Write `AGENT_ROSTER.md` in vault with chosen bindings
6. Update `hermes-setup.state` → `STEP=5`

**Mixed Mode Example:**
```yaml
agents:
  roster:
    orchestrator:
      provider: anthropic   # uses Claude proxy
    coder:
      provider: kimi        # uses Kimi API key directly
```

**Artifacts:** `.env` (600), `AGENT_ROSTER.md`

**Verification:**
```bash
stat -c '%a' .env | grep "600"
grep -q ".env" .gitignore
# API-keys mode: each enabled provider has a non-empty key
grep -q "ANTHROPIC_API_KEY=sk-" .env  # if orchestrator enabled
# Proxy mode: PROXY_MODE is true
grep -q "PROXY_MODE=true" .env
```

---

### Step 6 — Configure Delivery (Optional)

**Purpose:** Set up Telegram bots, Slack webhooks, or local-only mode.

**User Input:** Already collected in interview.

**What Happens:**
1. Read `delivery.platform` from `setup_answers.yaml`
2. If `telegram`: write bot config to `~/.hermes/profiles/telegram.yaml`
3. If `slack`: write webhook config to `~/.hermes/profiles/slack.yaml`
4. If `local-only` or `none`: nothing to do
5. Update `hermes-setup.state` → `STEP=6`

**Artifacts:** Delivery config in `~/.hermes/profiles/`

**Verification:**
```bash
# If Telegram enabled
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_HERMES}/getMe" | grep '"ok":true'
```

---

### Step 7 — Enable Auto-Start (Optional)

**Purpose:** systemd user services or screen/tmux sessions for persistent agents.

**User Input:** `install.auto_start` from interview.

**What Happens:**
1. If `systemd`:
   - Create `~/.config/systemd/user/hermes-orchestrator.service`
   - Create service files for each enabled agent
   - Run `systemctl --user daemon-reload`
2. If `screen`: create `~/hermes-start.sh` wrapper script
3. If `manual`: nothing to do
4. Update `hermes-setup.state` → `STEP=7`

**Artifacts:** systemd services or startup script.

**Verification:**
```bash
# If systemd
systemctl --user status hermes-orchestrator | grep -q "Loaded"
```

---

### Step 8 — Seed Starter Projects

**Purpose:** Copy health and/or finance starter templates if user enabled them.

**User Input:** `projects.health`, `projects.finance` from interview.

**What Happens:**
1. If `projects.health=true`: copy `templates/projects/health/` → `$VAULT_PATH/projects/health/`
2. If `projects.finance=true`: copy `templates/projects/finance/` → `$VAULT_PATH/projects/finance/`
3. Update `hermes-setup.state` → `STEP=8`

**Artifacts:** `projects/health/` and/or `projects/finance/` in vault.

**Verification:**
```bash
test -f "$VAULT_PATH/projects/health/index.md"
test -f "$VAULT_PATH/projects/finance/index.md"
```

---

### Step 9 — First Run — Hermes Reads Brain

**Purpose:** Simulate Hermes's first boot: read `brain/hot.md` + `Memories.md` and confirm the orchestrator can parse them.

**User Input:** None.

**What Happens:**
1. Run `bootstrap/lib/mock-orchestrator.py` which:
   - Reads `$VAULT_PATH/brain/hot.md`
   - Reads `$VAULT_PATH/brain/Memories.md`
   - Validates YAML frontmatter
   - Prints a summary of what Hermes would see on first boot
2. Update `hermes-setup.state` → `STEP=9`

**Artifacts:** `hermes-setup.state`

**Verification:**
```bash
python3 bootstrap/lib/mock-orchestrator.py "$VAULT_PATH"
# Must exit 0 and print "First-run simulation: OK"
```

---

### Step 10 — Smoke Test

**Purpose:** Prove the entire chain works.

**User Input:** None.

**What Happens:**
1. **API-keys mode:** For each enabled provider, call the `models` list endpoint, verify HTTP 200
2. **Proxy mode:** Check local proxy health endpoints and verify a chat completion round-trip
3. If proxy mode: verify `llm-cli-proxy`, `claude`, and/or `gemini` CLI binaries are installed
4. Validate vault `brain/hot.md` frontmatter is valid YAML
5. Verify `~/.hermes/` permissions are `700`
6. Verify `.env` permissions are `600`
7. If delivery enabled: ping the bot API
8. Write `smoke-test-report.json`
9. Update `hermes-setup.state` → `STEP=10`

**Artifacts:** `smoke-test-report.json`

**Verification:**
```bash
grep '"overall": "PASS"' smoke-test-report.json
```

---

## 4. Troubleshooting

### "No sudo available"
The kit falls back to user-space installs (`~/.local/bin`, `pip install --user`). If a step truly requires sudo, it will print exact manual commands for you to run.

### "Obsidian install hangs"
Use `--headless` mode. The vault works perfectly as plain Markdown without Obsidian.

### "API key rejected"
Check `smoke-test-report.json` for the specific provider failure. Common causes: expired key, wrong key format, provider outage.

### "Proxy not responding" (CLI proxy mode)
1. Verify proxies are running: `screen -ls` should show `proxy-claude` and/or `proxy-gemini`
2. Start proxies manually: `./scripts/start-proxies.sh`
3. Check proxy logs: `screen -r proxy-claude`
4. Ensure `claude` or `gemini` CLI is installed and authenticated:
   - `claude --version` should work
   - `gemini --version` should work
5. Common cause: CLI not authenticated. Run `claude login` or `gemini login` first.

### "I want to redo the interview"
Run `scripts/reverse-interview.py` to generate a new `setup_answers.yaml` from your current vault, then re-run `bootstrap/30-vault-seed.sh` and onward.

### "How do I rotate API keys?"
Run `scripts/rotate-keys.py`. It backs up the old `.env`, prompts for new keys, and validates them.

---

## 5. Post-Install

### Daily Usage

1. Open Obsidian (or your Markdown editor) at `$VAULT_PATH`
2. Edit `brain/hot.md` to set today's priorities
3. Chat with agents via Telegram (if configured) or CLI
4. Agent outputs sync to vault automatically

### Extending the System

- Add a new agent: edit `AGENT_ROSTER.md`, add provider config, run `bootstrap/40-agents-wire.sh`
- Add a new project: copy `templates/vault/projects/PROJECT_TEMPLATE.md`
- Add a new skill: write to `brain/Skills.md`

### Backups

The vault is plain Markdown — back it up with git:

```bash
cd "$VAULT_PATH"
git init
git add .
git commit -m "Initial vault state"
```

---

*End of runbook. If all 10 steps passed, Hermes is ready. Welcome to your Home-Brain.*
