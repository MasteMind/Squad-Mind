---
title: "[FEATURE] Add shellcheck to CI for all bash scripts"
labels: ["feature", "ci", "quality"]
---

## Description
No automated linting for shell scripts. Common bash bugs (unquoted variables, missing error handling) slip through.

## Proposed Solution
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

Fix existing violations first, then enforce in CI.

## Acceptance Criteria
- [ ] All `.sh` files pass `shellcheck`
- [ ] CI fails on shellcheck warnings
- [ ] CONTRIBUTING.md documents shellcheck requirement
