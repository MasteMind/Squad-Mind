---
title: "Support mixed provider mode per agent"
labels: ["feature", "high", "architecture"]
---

## Problem
The kit forces a global choice: ALL agents use API keys OR ALL agents use CLI proxies. Users may want a mix:
- Hermes (orchestrator) via Claude Max proxy
- Hephaestus (coder) via Kimi API key
- Clio (researcher) via Gemini proxy

## Proposed Fix
Per-agent provider configuration in `setup_answers.yaml`:

```yaml
agents:
  roster:
    orchestrator:
      provider: claude-proxy
    coder:
      provider: kimi-api
    researcher:
      provider: gemini-proxy
```

Update `40-agents-wire.sh` to write both proxy URLs and API keys to `.env`, and generate agent-specific configs in `~/.hermes/profiles/`.

## Acceptance Criteria
- [ ] Interview allows per-agent provider selection
- [ ] `.env` supports both proxy URLs and API keys simultaneously
- [ ] Smoke test validates each configured backend independently
- [ ] Documentation shows mixed-mode example
