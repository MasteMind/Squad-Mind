# llm-cli-proxy

`tools/llm-cli-proxy` is a vendored fork submodule
([MasteMind/llm-cli-proxy](https://github.com/MasteMind/llm-cli-proxy),
branch `squad-mind`) of upstream
[Slopedrop/llm-cli-proxy](https://github.com/Slopedrop/llm-cli-proxy) v1.0.1.
It wraps a locally-installed coding CLI in an OpenAI-compatible HTTP API
(`/v1/chat/completions`, `/v1/models`, `/health`), so squad agents whose
gateway speaks the OpenAI protocol can run on CLI subscriptions instead of
API keys.

In a squad-mind laptop setup, one proxy instance runs per CLI-backed agent
(default ports: hermes/claude :3456, clio :3457, hephaestus/codex :3458).
Laptop mode builds the proxy from this submodule — bootstrap stage 20
(`bootstrap/20-hermes-core.sh`) runs `npm ci && npm run build` and exposes
`dist/index.js` via the `~/.hermes/llm-cli-proxy-link` symlink; the npm
registry package is only a fallback when the submodule isn't checked out.
Our deltas on top of upstream are tracked as patches in
[patches/README.md](../patches/README.md).

## Providers

| Provider | Binary | Notes |
|---|---|---|
| `claude` | `claude` | NDJSON stream, `--resume` chaining, optional `--agent` passthrough, `ANTHROPIC_BASE_URL` env passthrough |
| `codex` | `codex` | NDJSON (`exec --json`), `resume --last` chaining, `--skip-git-repo-check` for non-repo workspaces |
| `agy` | `agy` | Antigravity CLI. Plain-text stdout (no NDJSON) — the proxy synthesizes events; conversation id read from `~/.gemini/antigravity-cli/cache/last_conversations.json`; model set via AGY's `settings.json` (no `--model` flag) |
| `gemini` | `gemini` | NDJSON stream, `--resume` chaining, `--skip-trust` for operator-set workspaces |
| `talaria` / `ollama` | `ollama` | Local-model providers (fork-only); talaria isolates the squad's Ollama env injection |

## Diff-context-forwarding

OpenAI-protocol clients (the gateway) replay the **full** conversation
history on every request. But the proxied CLI already holds that history in
its own resumed session (`--resume` / `--conversation`). Naively forwarding
the whole array makes the CLI re-ingest an ever-growing transcript each
turn — token cost and latency grow quadratically over a long squad session,
which is exactly the shape of gateway traffic (agents accumulate hundreds of
turns per day).

The proxy therefore prefix-diffs before forwarding:

- Each message is fingerprinted (`sha1` over a normalized
  `{role, content, name, tool_call_id, tool_calls}` projection).
- The session manager remembers the fingerprint sequence of everything the
  CLI session has already ingested — prior inputs plus each assistant reply
  it produced (committed only after a successful turn; the single-concurrency
  request queue keeps this bookkeeping race-free).
- If the incoming history's leading fingerprints exactly match, only the new
  tail is sent; the CLI supplies the older context itself via resume.
- Full context is re-sent (and the CLI session reset to fresh) when no
  session exists yet, the prefix mismatches (client edited/forked history),
  or the tail is empty (identical replay).

Set `LLM_CLI_PROXY_NO_DIFF=1` to disable diffing and restore upstream
"send everything every turn" behavior. `LLM_CLI_PROXY_REQUEST_TIMEOUT_MS`
overrides the per-request ceiling (default 30 min).
