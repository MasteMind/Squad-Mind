---
title: "Vault templates should enforce YAML frontmatter on generated files"
labels: ["feature", "medium", "quality", "templates"]
---

## Problem
The kit generates markdown files from templates, but there's no enforcement that output files contain required YAML frontmatter (`type`, `status`, `date`, `description`). This breaks agent parsing and wiki indexing for users.

## Proposed Fix
1. Ensure ALL templates in `templates/vault/` include frontmatter with variable placeholders:
   ```markdown
   ---
   type: project
   status: active
   date: ${DATE}
   description: "${DESCRIPTION}"
   ---
   ```
2. Add a post-seed validation step in `30-vault-seed.sh`:
   ```bash
   find "$VAULT_PATH" -name '*.md' -not -path '*/.obsidian/*' | while read f; do
       if ! grep -q '^---$' "$f"; then
           echo "WARNING: Missing frontmatter: $f"
       fi
   done
   ```
3. Add `scripts/check-frontmatter.py` for CI/pre-commit.

## Acceptance Criteria
- [ ] All `.md` templates include frontmatter
- [ ] `30-vault-seed.sh` warns about missing frontmatter
- [ ] Optional: CI enforces frontmatter on PRs
