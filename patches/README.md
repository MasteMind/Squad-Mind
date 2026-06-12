# llm-cli-proxy patches

Our deltas on top of upstream [Slopedrop/llm-cli-proxy](https://github.com/Slopedrop/llm-cli-proxy) v1.0.1 (54baac6), carried on the `squad-mind` branch of [MasteMind/llm-cli-proxy](https://github.com/MasteMind/llm-cli-proxy) — the branch the `tools/llm-cli-proxy` submodule is pinned to.

- `0001-feat-add-environment-variable-support-to-provider-co.patch` — env-var support in provider config (originally 4440bac). Upstream-PR candidate.
- `0002-refactor-isolate-ollama-env-injection-to-talariaProv.patch` — isolate Ollama env injection to talariaProvider (originally 33d889f). Fork-only; talaria is squad-specific.
- `0003-feat-add-agy-provider.patch` — Antigravity CLI (`agy`) provider: plain-text stdout handling (`emitsJson: false`), session-id capture from `last_conversations.json`, model selection via AGY's settings file. Fork-only; Clio's proxy (:3457) depends on it.
- `0004-feat-diff-context-forwarding-prefix-diff-session-con.patch` — prefix-diff incoming OpenAI conversation history against what the CLI's resumed session already ingested, forwarding only the new tail. Gateways replay full history every turn, so without this each turn through a CLI proxy re-sends the entire transcript — token cost and latency grow quadratically over long squad sessions. Also routes codex through the CLI (resume chaining), adds `--agent`/model passthrough, and a configurable per-request timeout. Upstream-PR candidate.

Regenerate with: `git -C tools/llm-cli-proxy format-patch 54baac6..squad-mind -o "$(pwd)/patches"` (from the superproject root)
