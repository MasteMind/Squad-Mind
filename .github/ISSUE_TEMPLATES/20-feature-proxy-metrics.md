---
title: "[FEATURE] Add /metrics endpoint to llm-cli-proxy for monitoring"
labels: ["feature", "proxy", "monitoring"]
---

## Description
No visibility into proxy performance: request latency, error rates, session continuity success/failure.

## Proposed Metrics
```
# /metrics (Prometheus-compatible)
proxy_requests_total{provider="claude",status="200"} 42
proxy_requests_total{provider="claude",status="429"} 3
proxy_session_resumes_total{provider="claude"} 41
proxy_session_new_total{provider="claude"} 1
proxy_latency_seconds_bucket{le="1.0"} 38
proxy_latency_seconds_bucket{le="5.0"} 41
proxy_latency_seconds_bucket{le="10.0"} 42
```

## Use Cases
- Alert on high error rates
- Track session continuity health
- Optimize timeout values

## Acceptance Criteria
- [ ] `GET /metrics` returns Prometheus-compatible text
- [ ] Counters: requests, errors, session resumes, session creations
- [ ] Histogram: request latency
- [ ] Optional: expose as OpenTelemetry
