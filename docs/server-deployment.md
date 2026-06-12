# Server Deployment Runbook

Deploy Squad-Mind for a team on a shared Ubuntu VM: one team per VM, systemd
SYSTEM units, a single `hermes` service user, everything under
`/srv/squad/{brain,hermes,archive,secrets}`. The installer
([deploy/server-install.sh](../deploy/server-install.sh)) is idempotent —
re-running it is always safe.

> **LICENSING — read before you fill in any credentials.**
> Claude Max / ChatGPT Codex / Gemini Advanced are **per-human consumer
> subscriptions**. Pointing a shared team server at personal OAuth/CLI tokens
> violates ToS, creates bus-factor-1 auth, and makes spend un-attributable.
> Use **API keys billed to a team project** — Vertex AI recommended on GCP
> (org billing + IAM); direct Anthropic/OpenAI/Gemini API keys also fine.
> CLI proxies (`llm-proxy@.service`, `--cli-proxy-dev`) are dev/laptop mode
> only and are never enabled on servers.

## 1. Prerequisites

- **Ubuntu/Debian VM with systemd**, root access. Internet egress to your LLM
  providers and Slack (Socket Mode — no inbound HTTP needed).
- **Sizing:**
  - Without local Talaria (default): an `e2-standard-4`-class VM (4 vCPU /
    16 GB) is plenty. Talaria can instead be rebound to an API flash model via
    `agents.roster.talaria` in the answers file.
  - With `--talaria-local` (Ollama on-box): the default junior model needs
    roughly **8–10 GB RAM resident** — plan an `e2-standard-8`-class VM
    (32 GB). See [deploy/systemd/ollama.service.notes.md](../deploy/systemd/ollama.service.notes.md).
- A Slack workspace where you can create an app.
- (Recommended) An empty git remote for the team brain, and a GCS bucket for
  nightly backups.

## 2. Install

```bash
# 1. Get the kit (submodules carry the vendored proxy tooling)
git clone --recurse-submodules <your-squad-mind-repo-url>
cd Squad-Mind

# 2. Run the installer as root
sudo deploy/server-install.sh \
    --team-name "Checkout Platform" \
    --admin-name "Alex" --admin-email alex@example.com \
    --timezone "Europe/London" \
    --brain-git-url git@github.com:org/team-brain.git
    # add --talaria-local only if the VM is sized for Ollama
```

The installer creates the `hermes` user and `/srv/squad` layout, installs
packages and the hermes-agent venv, runs the bootstrap stages headless, wires
per-profile gateways (dispatcher only in the `default` instance), installs the
systemd units from [deploy/systemd/](../deploy/systemd/README.md), and enables
— but does not start — `squad-mind.target`.

```bash
# 3. Fill the secrets file (template: deploy/env/server.env.example)
sudo vim /srv/squad/secrets/.env       # root:hermes 640 — keep it that way
```

Fill in: provider API keys, `SLACK_BOT_TOKEN` / `SLACK_APP_TOKEN`,
`SLACK_ALLOWED_USERS`, and optionally `SLACK_ALERT_WEBHOOK` and
`BACKUP_GCS_BUCKET`.

```bash
# 4. Create the Slack app from the manifest
#    https://api.slack.com/apps -> Create New App -> From an app manifest
#    Paste deploy/slack/app-manifest.yml, install to the workspace,
#    copy the xoxb-/xapp- tokens into /srv/squad/secrets/.env.

# 5. Brain git remote (skip if --brain-git-url was given)
sudo -u hermes git -C /srv/squad/brain remote add origin <url>
sudo -u hermes git -C /srv/squad/brain push -u origin main

# 6. Start
sudo systemctl start squad-mind.target
```

## 3. Verify

```bash
systemctl status squad-mind.target            # active
systemctl status 'hermes-gateway@*'           # default, hephaestus, clio (+ talaria)
systemctl list-timers 'vault-autocommit*' 'squad-backup*' 'audit-export*'
```

Then the round-trip test: in Slack, invite the bot to your squad channel and
post `@squad hello — who's on the team?`. A reply within ~30 s from the
orchestrator means tokens, allowlist, and the gateway are all good. If nothing
comes back, see Troubleshooting.

## 4. Operations

### Backups

`squad-backup.timer` runs [deploy/scripts/backup-to-gcs.sh](../deploy/scripts/backup-to-gcs.sh)
nightly: consistent sqlite `.backup` copies of `kanban.db`/`state.db` plus a
`tar.zst` of `HERMES_HOME` (venv/caches excluded) into
`/srv/squad/archive/backups/` (last 14 kept), uploaded to `$BACKUP_GCS_BUCKET`
when set. The **brain is not in this archive** — it is a git repo; its backup
is its remote.

### Restore

```bash
# 0. Stop everything
sudo systemctl stop squad-mind.target
sudo systemctl stop vault-autocommit.timer squad-backup.timer audit-export.timer

# 1. Get the archive (local, or pull from GCS)
gcloud storage cp gs://<bucket>/backups/squad_<ts>.tar.zst /srv/squad/archive/backups/

# 2. Move the broken runtime aside and extract
sudo mv /srv/squad/hermes /srv/squad/hermes.broken.$(date +%F)
sudo mkdir /srv/squad/restore
sudo tar --zstd -xf /srv/squad/archive/backups/squad_<ts>.tar.zst -C /srv/squad/restore
sudo mv /srv/squad/restore/hermes /srv/squad/hermes
sudo mv /srv/squad/restore/dbs/kanban.db /srv/squad/hermes/kanban.db
sudo mv /srv/squad/restore/dbs/state.db /srv/squad/hermes/state.db 2>/dev/null || true
sudo rm -rf /srv/squad/restore
sudo chown -R hermes:hermes /srv/squad/hermes

# 3. Recreate the venv (excluded from backups on purpose)
sudo -u hermes python3 -m venv /srv/squad/hermes/venv
sudo -u hermes /srv/squad/hermes/venv/bin/pip install hermes-agent pyyaml

# 4. Brain (only if /srv/squad/brain was lost): re-clone from the remote,
#    then re-run the installer once — it is idempotent and re-creates the
#    per-agent workspace symlinks a fresh clone loses.
sudo -u hermes git clone <brain-remote-url> /srv/squad/brain
sudo deploy/server-install.sh --brain-git-url <brain-remote-url> [your original flags]

# 5. Start and verify (section 3)
sudo systemctl start squad-mind.target
```

Drill this restore on a schedule — see [phase2-hardening.md](phase2-hardening.md).

### Key rotation

```bash
sudo scripts/rotate-keys.py --env-file /srv/squad/secrets/.env
sudo systemctl restart squad-mind.target
```

The script backs up the old file, prompts for new keys, validates them, and
preserves the `root:hermes 640` ownership/permissions.

### Tenant archive

When a working session's cards are all done, cold-archive its kanban workspace
(the brain project dir stays — it's the durable record):

```bash
sudo -u hermes deploy/scripts/archive-tenant.sh <tenant-slug>
# refuses while non-done cards exist; --force overrides
```

## 5. Troubleshooting

**Gateway logs** — first stop for everything:

```bash
journalctl -u 'hermes-gateway@*' -f          # all gateways, live
journalctl -u hermes-gateway@default -e      # just the orchestrator
```

**Slack mention gets no reply.** Check, in order: bot invited to the channel;
your Slack user ID is in `SLACK_ALLOWED_USERS`; `SLACK_BOT_TOKEN`/
`SLACK_APP_TOKEN` filled and the gateway restarted after editing
`/srv/squad/secrets/.env`; `journalctl -u hermes-gateway@default` for auth
errors.

**Dispatcher single-owner rule.** Exactly one gateway runs the kanban
dispatcher: the `default` instance (its drop-in sets the root `HERMES_HOME`,
whose config carries `kanban.dispatch_in_gateway: true`). Every other profile's
`config.yaml` has it `false`. Tasks claimed twice → a second dispatcher is
running; tasks never picked up → the default gateway is down or the flag got
flipped.

**Task stuck in `ready` forever, zero events.** Almost always a reserved-name
assignee: orchestrator-owned cards must use `--assignee default`, never
`hermes` — the dispatcher silently skips reserved names.

**Vault-autocommit conflict alert.** The timer never force-pushes; on a rebase
conflict it aborts and alerts via `SLACK_ALERT_WEBHOOK` (journal-only if
unset). Resolve by hand as the service user:

```bash
sudo -u hermes git -C /srv/squad/brain status
# resolve, commit, push — the next 5-min tick resumes normal service
```

Usually caused by a human pushing directly to the brain's main branch instead
of going through a PR (see [ONBOARDING.md](../ONBOARDING.md)).

**Ollama / Talaria cold start.** First call after boot pulls or loads the
model; check `systemctl status ollama` and RAM headroom (sizing note in
section 1).
