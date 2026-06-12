# ollama.service — notes (no unit file shipped here)

The native Ollama installer (`curl -fsSL https://ollama.com/install.sh | sh`)
creates and enables its own `ollama.service` system unit — do not hand-write
one. `deploy/server-install.sh` runs that installer only when invoked with
`TALARIA_LOCAL=1`, then enables `hermes-gateway@talaria.service` and adds it
to `squad-mind.target`.

## Sizing

- Talaria's default model (`qwen3.5:9b-q4_K_M`, see `models.lock.yaml`) needs
  roughly **8–10 GB RAM** resident — plan an e2-standard-8 (32 GB) class VM.
- **Cheaper alternative:** keep `TALARIA_LOCAL` off and rebind talaria to an
  API flash model (e.g. `gemini-2.5-flash`) via `agents.roster.talaria` in
  the answers file — an e2-standard-4 then suffices and no Ollama runs.

After install, pull the model once: `sudo -u hermes ollama pull qwen3.5:9b-q4_K_M`
(or let the first talaria call trigger the pull, accepting the cold start).
