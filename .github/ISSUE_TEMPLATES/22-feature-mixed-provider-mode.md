---
title: "[FEATURE] Support mixed mode: some agents via API, some via proxy"
labels: ["feature", "architecture"]
---

## Description
Current setup forces all agents to use either API keys OR proxy mode. Users may want:
- Hermes (orchestrator) via Claude Max proxy
- Hephaestus (coder) via Kimi API key
- Clio (researcher) via Gemini proxy

## Proposed Solution
Per-agent provider configuration in `setup_answers.yaml`:

```yaml
agents:
  roster:
    orchestrator:
      provider: claude-proxy    # uses CLAUDE_PROXY_URL
    coder:
      provider: kimi-api        # uses KIMI_API_KEY
    researcher:
      provider: gemini-proxy    # uses GEMINI_PROXY_URL
```

Update `40-agents-wire.sh` to configure each agent's backend individually.

## Acceptance Criteria
- [ ] Each agent can have independent provider config
- [ ] Smoke test validates all configured backends
- [ ] `.env` supports both proxy URLs and API keys simultaneously
