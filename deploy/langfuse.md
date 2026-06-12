# Langfuse (optional, OFF by default)

hermes-agent ships an opt-in observability plugin
(`plugins/observability/langfuse`) that traces every gateway turn — LLM
calls, tool calls, token counts — and attributes **cost per trace, tagged by
profile**, so you can see what Hermes vs Hephaestus vs Clio spend.

**Deferrable.** journald + the kanban `task_events` table (exported nightly
to `/srv/squad/brain/audit/` by `audit-export.timer`) already answer
*who did what, when*. Langfuse answers *what it cost*. Enable it when spend
attribution becomes a question; nothing here is wired on by default.

## Enable (per profile)

The plugin's config surface is environment variables, not `config.yaml`
(verified against the plugin's README/plugin.yaml). It fails open: without
the SDK or credentials the hooks no-op silently.

1. Install the SDK into the squad venv:

   ```bash
   sudo -u hermes /srv/squad/hermes/venv/bin/pip install langfuse
   ```

2. Add credentials to `/srv/squad/secrets/.env` (all gateway units load it):

   ```bash
   HERMES_LANGFUSE_PUBLIC_KEY=pk-lf-...
   HERMES_LANGFUSE_SECRET_KEY=sk-lf-...
   HERMES_LANGFUSE_BASE_URL=https://cloud.langfuse.com   # or self-hosted
   # Optional tuning:
   #HERMES_LANGFUSE_ENV=production
   #HERMES_LANGFUSE_RELEASE=v1.0.0
   #HERMES_LANGFUSE_SAMPLE_RATE=0.5
   ```

3. Enable the plugin for each profile that should report, then restart:

   ```bash
   sudo -u hermes HERMES_HOME=/srv/squad/hermes \
       /srv/squad/hermes/venv/bin/python -m hermes_cli.main \
       plugins enable observability/langfuse
   # repeat with HERMES_HOME=/srv/squad/hermes/profiles/<id> per profile
   systemctl restart squad-mind.target
   ```

## Disable

```bash
... plugins disable observability/langfuse
systemctl restart squad-mind.target
```
