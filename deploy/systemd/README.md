# deploy/systemd — system-scope units (installed by ../server-install.sh)

- `squad-mind.target` — umbrella; Wants the three core gateways; WantedBy=multi-user.target.
- `hermes-gateway@.service` — one gateway per profile (`default` = orchestrator/dispatcher via the installer-written drop-in `hermes-gateway@default.service.d/10-root-profile.conf`; non-default profiles get `kanban.dispatch_in_gateway: false` in their profile config.yaml).
- `llm-proxy@.service` — dev/laptop mode only (licensing header inside); never enabled on servers, not pulled in by the target.
- `ollama.service` — created by the native Ollama installer when `TALARIA_LOCAL=1`; see `ollama.service.notes.md`.
- `vault-autocommit.{service,timer}` — every 5 min: commit + pull --rebase + push `/srv/squad/brain` (never force-pushes; conflict → abort + Slack alert via `SLACK_ALERT_WEBHOOK`). Runs `deploy/scripts/vault-autocommit.sh`.
- `squad-backup.{service,timer}` — nightly: sqlite `.backup` of kanban.db/state.db + tar.zst of HERMES_HOME to `/srv/squad/archive/backups/` (keep 14), upload to `$BACKUP_GCS_BUCKET` when set. Runs `deploy/scripts/backup-to-gcs.sh`.
- `audit-export.{service,timer}` — nightly: JSONL export of yesterday's `task_events`/`task_comments`/`task_runs` rows into `/srv/squad/brain/audit/YYYY-MM-DD.jsonl` (committed by the next autocommit tick). Runs `deploy/scripts/export-audit.sh`.

Enable order: install units → `systemctl daemon-reload` → `systemctl enable squad-mind.target hermes-gateway@{default,hephaestus,clio}` (+ `hermes-gateway@talaria` if local Ollama) → `systemctl enable --now vault-autocommit.timer squad-backup.timer audit-export.timer` → fill `/srv/squad/secrets/.env` → `systemctl start squad-mind.target`.
