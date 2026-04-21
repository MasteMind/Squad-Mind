---
title: "[MEDIUM] 12+ broken wikilinks and missing referenced files"
labels: ["quality", "medium", "vault"]
---

## Description
Wikilinks like `[[Page Name]]` point to files that don't exist. This breaks navigation in Obsidian and confuses agents.

## Examples Found
- `OneArc-DeepFakeFlagger/research/overview.md` links to non-existent files
- `wiki/index.md` references entities/sources that haven't been created
- `agents/hermes/SOUL.md` references agents without their own SOUL.md files

## Fix
1. Create missing files or update links:
   ```bash
   # Find all broken wikilinks
   grep -roP '\[\[([^\]]+)\]\]' . --include='*.md' | sort -u
   ```
2. For each broken link, either:
   - Create the target file with template frontmatter
   - Update the link to point to an existing file
   - Remove the link if no longer relevant

## Acceptance Criteria
- [ ] `grep -r '\[\[' . --include='*.md'` shows only links to existing files
- [ ] `wiki/index.md` links only to created pages
