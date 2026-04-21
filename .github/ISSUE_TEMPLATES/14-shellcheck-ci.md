---
title: "Add shellcheck to CI"
labels: ["feature", "low", "ci", "quality"]
---

## Problem
No automated linting for shell scripts. Common bash bugs (unquoted variables, missing error handling) can slip into releases.

## Proposed Fix
GitHub Actions workflow:

```yaml
# .github/workflows/shellcheck.yml
name: ShellCheck
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: './bootstrap ./scripts'
```

Fix all existing violations before enabling.

## Acceptance Criteria
- [ ] All `.sh` files pass `shellcheck`
- [ ] CI fails on shellcheck warnings
- [ ] Documented in CONTRIBUTING.md
