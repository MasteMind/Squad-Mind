---
title: "[HIGH] ~85 vault files missing required YAML frontmatter"
labels: ["quality", "high", "vault"]
---

## Description
AGENTS.md requires frontmatter with `type`, `status`, `date`, `description` on all markdown files. Audit found ~85 files without it, breaking automated parsing by agents.

## Affected Areas
- `daily/` notes
- `projects/` subdirectories
- `wiki/concepts/` and `wiki/entities/`
- Some `agents/` files

## Impact
- Agents can't determine file type or status
- Wiki index can't auto-generate
- Missing metadata breaks sorting and filtering
- `mock-orchestrator.py` validation fails

## Fix
1. Create a script to batch-add minimal frontmatter:
   ```bash
   # Add frontmatter to files missing it
   for f in $(find . -name '*.md' -not -path './.obsidian/*'); do
     if ! grep -q '^---$' "$f"; then
       # Insert frontmatter at top
     fi
   done
   ```
2. Update AGENTS.md with clear frontmatter exemptions (e.g., `.obsidian/`, `README.md`)
3. Add a CI check or pre-commit hook

## Acceptance Criteria
- [ ] `find vault/ -name '*.md' | xargs grep -L '^---$'` returns only exempted files
- [ ] All exempted files documented in AGENTS.md
- [ ] Pre-commit hook or CI enforces frontmatter
