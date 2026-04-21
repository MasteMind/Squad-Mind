---
title: "[FEATURE] Pre-commit hooks for frontmatter and secrets"
labels: ["feature", "ci", "quality", "security"]
---

## Description
No checks prevent commits of:
- Missing frontmatter on markdown files
- Accidentally committed `.env` files
- API keys in code

## Proposed Solution
`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: check-frontmatter
        name: Check Markdown frontmatter
        entry: scripts/check-frontmatter.py
        language: python
        files: '\.md$'
      - id: check-secrets
        name: Check for exposed secrets
        entry: scripts/check-secrets.py
        language: python
        files: '.*'
```

## Acceptance Criteria
- [ ] `pre-commit install` works in repo
- [ ] Commits blocked if markdown lacks required frontmatter
- [ ] Commits blocked if `.env` or API keys detected
- [ ] Documented in README.md
