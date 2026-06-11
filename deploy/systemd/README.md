# deploy/systemd — system-scope units (installed by ../server-install.sh)

- `squad-mind.target` — umbrella; Wants the three core gateways; WantedBy=multi-user.target.
- `hermes-gateway@.service` — one gateway per profile (`default` = orchestrator/dispatcher via the installer-written drop-in `hermes-gateway@default.service.d/10-root-profile.conf`; non-default profiles get `kanban.dispatch_in_gateway: false` in their profile config.yaml).
- `llm-proxy@.service` — dev/laptop mode only (licensing header inside); never enabled on servers, not pulled in by the target.
- `ollama.service` — created by the native Ollama installer when `TALARIA_LOCAL=1`; see `ollama.service.notes.md`.

Enable order: install units → `systemctl daemon-reload` → `systemctl enable squad-mind.target hermes-gateway@{default,hephaestus,clio}` (+ `hermes-gateway@talaria` if local Ollama) → fill `/srv/squad/secrets/.env` → `systemctl start squad-mind.target`.
