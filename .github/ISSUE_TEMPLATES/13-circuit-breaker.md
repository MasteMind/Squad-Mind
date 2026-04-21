---
title: "Document circuit breaker / retry strategy for proxy failures"
labels: ["feature", "medium", "proxy", "reliability"]
---

## Problem
When a CLI proxy hits rate limits or crashes, there's no documented retry or fallback strategy. Users don't know how Hermes will behave or how to configure resilience.

## Proposed Fix
Add a resilience guide to the docs and ship a wrapper or config template:

```yaml
# docs/RESILIENCE.md or template in ~/.hermes/config.yaml
resilience:
  max_retries: 3
  backoff_seconds: [1, 2, 4]
  fallback_provider: ollama  # or another proxy port
  circuit_breaker:
    failure_threshold: 5
    recovery_timeout: 60
```

For the bootstrap kit, add a `--resilience` flag that configures sensible defaults.

## Acceptance Criteria
- [ ] Documentation explains what happens when proxy fails
- [ ] Sensible retry defaults documented
- [ ] Fallback provider configuration explained
- [ ] Example: "If Claude proxy fails, fall back to Gemini proxy"
