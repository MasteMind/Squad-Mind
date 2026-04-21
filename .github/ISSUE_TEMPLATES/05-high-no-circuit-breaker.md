---
title: "[HIGH] No circuit breaker for proxy failures"
labels: ["reliability", "high", "proxy"]
---

## Description
When Claude CLI hits rate limits, budget blocks, or network errors, Hermes retries blindly with no backoff or circuit breaker. This can:
- Exacerbate rate limiting
- Waste tokens on doomed requests
- Cause cascading failures across all agents

## Scenarios
- Claude Max subscription hits daily limit → all requests fail → Hermes retries immediately → account flagged
- Proxy crashes mid-request → Hermes retries → hits dead proxy again
- Network partition → infinite retry loop

## Fix
Add a simple circuit breaker to Hermes config or proxy wrapper:

```yaml
# In ~/.hermes/config.yaml or proxy config
circuit_breaker:
  failure_threshold: 5
  recovery_timeout: 60
  half_open_requests: 1
```

Or implement in the bootstrap kit as a proxy wrapper script that:
1. Tracks consecutive failures per provider
2. Returns 503 after threshold with `Retry-After` header
3. Attempts recovery after timeout

## Acceptance Criteria
- [ ] After 5 consecutive failures, proxy returns 503 for 60 seconds
- [ ] Hermes respects `Retry-After` and uses fallback provider if configured
- [ ] Metrics logged: failures, recoveries, circuit state
