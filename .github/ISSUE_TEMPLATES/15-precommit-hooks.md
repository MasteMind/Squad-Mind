---
title: "Pre-commit hooks for secrets and markdown frontmatter"
labels: ["feature", "low", "ci", "security"]
---

## Problem
No automated checks prevent commits of:
- Missing frontmatter on markdown files
- Accidentally committed `.env` files
- API keys in code

## Proposed Fix
`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: check-secrets
        name: Check for exposed secrets
        entry: scripts/check-secrets.py
        language: python
        files: '.*'
      - id: check-env-not-committed
        name: Prevent .env in git
        entry: 'bash -c "git diff --cached --name-only | grep -q \"\.env$\" && exit 1 || exit 0"'
        language: system
```

## Acceptance Criteria
- [ ] `pre-commit install` works
- [ ] Commits blocked if `.env` staged
- [ ] Commits blocked if API key patterns detected
- [ ] Documented in README
