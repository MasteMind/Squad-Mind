#!/usr/bin/env python3
"""
mock-orchestrator.py
Simulates Hermes's first boot by reading brain/hot.md and Memories.md.
Used in Step 9 of the runbook.
"""

import sys
import re
from pathlib import Path


def read_frontmatter(path: Path) -> dict:
    try:
        text = path.read_text()
        match = re.search(r'^---\s*$(.*?)^---\s*$', text, re.MULTILINE | re.DOTALL)
        if match:
            import yaml
            return yaml.safe_load(match.group(1)) or {}
    except Exception as e:
        print(f"Warning: Could not parse frontmatter in {path}: {e}")
    return {}


def main():
    vault_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Documents' / 'Home-Brain'

    hot_md = vault_path / 'brain' / 'hot.md'
    memories_md = vault_path / 'brain' / 'Memories.md'

    print(f"Vault path: {vault_path}")
    print("")

    if hot_md.exists():
        fm = read_frontmatter(hot_md)
        print(f"✅ hot.md found")
        print(f"   Type: {fm.get('type', 'N/A')}")
        print(f"   Status: {fm.get('status', 'N/A')}")
    else:
        print(f"❌ hot.md NOT found")
        sys.exit(1)

    if memories_md.exists():
        fm = read_frontmatter(memories_md)
        print(f"✅ Memories.md found")
        print(f"   Type: {fm.get('type', 'N/A')}")
    else:
        print(f"❌ Memories.md NOT found")
        sys.exit(1)

    print("")
    print("First-run simulation: OK")
    print("Hermes would read these files at session start and know:")
    print("  - Current priorities (from hot.md)")
    print("  - User profile (from Memories.md)")


if __name__ == '__main__':
    main()
