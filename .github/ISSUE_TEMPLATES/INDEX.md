# Agent Swarm Audit Results

*Comprehensive system analysis by kimi agent swarm (2026-04-21).*

## Summary

| Category | Count |
|----------|-------|
| Critical | 4 |
| High | 5 |
| Medium | 8 |
| Low | 3 |
| Feature | 7 |
| **Total** | **27** |

---

## Critical (Fix Immediately)

| # | Issue | File/Area | Risk |
|---|-------|-----------|------|
| 01 | [Proxies bind to 0.0.0.0](01-critical-proxy-bind.md) | llm-cli-proxy | Unauthorized network access |
| 02 | [No auto-restart on crash](02-critical-proxy-auto-restart.md) | screen sessions | Silent total failure |
| 03 | [Exposed secrets in runtime](03-critical-exposed-secrets.md) | ~/.hermes/, brain/ | Key compromise |
| 04 | [Stale systemd service](04-critical-stale-systemd-service.md) | systemd units | Boot conflicts |

## High (Fix This Week)

| # | Issue | File/Area | Risk |
|---|-------|-----------|------|
| 05 | [No circuit breaker](05-high-no-circuit-breaker.md) | Hermes/proxy | Cascade failures |
| 06 | [No log rotation](06-high-no-log-rotation.md) | /tmp/proxy-*.log | Disk exhaustion |
| 07 | [Missing bootstrap stages 6–9](07-high-bootstrap-missing-stages.md) | bootstrap/ | Incomplete setup |
| 08 | [~85 files missing frontmatter](08-high-missing-frontmatter.md) | vault/ | Broken agent parsing |

## Medium (Fix This Month)

| # | Issue | File/Area | Risk |
|---|-------|-----------|------|
| 09 | [Broken wikilinks](09-medium-broken-wikilinks.md) | vault/ | Navigation broken |
| 10 | [No port conflict detection](10-medium-port-conflicts.md) | start-proxies.sh | Startup failures |
| 11 | [Cron invocation bug](11-medium-cron-bug.md) | nightly_brain_sync.sh | Sync fails silently |
| 12 | [Broken fallback provider](12-medium-hermes-fallback-broken.md) | ~/.hermes/config.yaml | Auth cascade |
| 13 | [Unsafe env export](13-medium-env-export-bug.md) | 50-smoke-test.sh | Script failures |
| 14 | [Stale PID file](14-medium-stale-pid-file.md) | gateway.pid | Wrong process killed |
| 15 | [1.8GB duplicate binary](15-medium-1.8gb-duplication.md) | profiles/argus/ | Disk waste |
| 16 | [Missing agent SOULs](16-medium-missing-agent-souls.md) | agents/ | Incomplete roster |

## Low (Polish)

| # | Issue | File/Area | Risk |
|---|-------|-----------|------|
| 17 | [install.sh TTY bug](17-low-install-sh-tty.md) | install.sh | curl pipe fails |
| 18 | [sed -i portability](18-low-sed-portability.md) | common.sh | macOS failure |
| 19 | [Unquoted glob](19-low-uninstall-glob.md) | uninstall.sh | Harmless noise |

## Features

| # | Issue | Area | Value |
|---|-------|------|-------|
| 20 | [Proxy metrics endpoint](20-feature-proxy-metrics.md) | proxy | Monitoring |
| 21 | [Auto-start on boot](21-feature-auto-start-proxies.md) | proxy | Reliability |
| 22 | [Mixed provider mode](22-feature-mixed-provider-mode.md) | architecture | Flexibility |
| 23 | [Vault backup](23-feature-vault-backup.md) | vault | Safety |
| 24 | [Health dashboard](24-feature-health-dashboard.md) | monitoring | Ops visibility |
| 25 | [ShellCheck CI](25-feature-shellcheck-ci.md) | ci | Code quality |
| 26 | [Pre-commit hooks](26-feature-precommit-hooks.md) | ci | Quality + security |
| 27 | [Docker health checks](27-feature-docker-healthchecks.md) | docker | Reliability |

---

## How to Use These Issues

1. Copy each `.md` file content into a new GitHub Issue
2. Apply the labels from the frontmatter
3. Start with Critical issues (01–04)
4. Triage based on your current priorities

## Agent Credits

- **kimi** (Moonshot AI) — System analysis, issue compilation, fix proposals
- **Clio** (Gemini) — Research and cross-reference validation
- **Solon** (DeepSeek) — Architecture critique and risk assessment
- **Hephaestus** (Kimi) — Bootstrap kit code review
