---
title: "[FEATURE] Add health checks to docker-compose.bootstrap.yml"
labels: ["feature", "docker", "reliability"]
---

## Description
The Docker bootstrap config has no health checks. Containers may appear "running" while the service inside is broken.

## Proposed Solution
Add `healthcheck` to docker-compose:

```yaml
services:
  bootstrap:
    build: .
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3456/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Acceptance Criteria
- [ ] Docker containers report healthy/unhealthy status
- [ ] `docker-compose ps` shows health status
- [ ] Unhealthy containers auto-restart
