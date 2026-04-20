#!/usr/bin/env python3
"""
reverse-interview.py
Reads the current vault + .env and emits an updated setup_answers.yaml.
Useful when you want to regenerate the interview from an edited config.
"""

import os
import re
import yaml
import sys
from pathlib import Path
from datetime import datetime


def extract_frontmatter(path: str) -> dict:
    """Read YAML frontmatter from a markdown file."""
    try:
        with open(path) as f:
            content = f.read()
        match = re.search(r'^---\s*$(.*?)^---\s*$', content, re.MULTILINE | re.DOTALL)
        if match:
            return yaml.safe_load(match.group(1)) or {}
    except Exception:
        pass
    return {}


def read_memories(vault_path: str) -> dict:
    """Parse brain/Memories.md for user info."""
    memories_path = Path(vault_path) / "brain" / "Memories.md"
    if not memories_path.exists():
        return {}

    text = memories_path.read_text()
    result = {}

    # Simple regex extraction
    m = re.search(r'\*\*Name:\*\*\s*(.+)', text)
    if m:
        result['name'] = m.group(1).strip()

    m = re.search(r'\*\*Email:\*\*\s*(\S+)', text)
    if m:
        result['email'] = m.group(1).strip()

    m = re.search(r'\*\*Timezone:\*\*\s*(\S+)', text)
    if m:
        result['timezone'] = m.group(1).strip()

    m = re.search(r'\*\*Household:\*\*\s*(\S+)', text)
    if m:
        result['household'] = m.group(1).strip()

    return result


def read_env() -> dict:
    """Read .env for provider keys and paths."""
    env = {}
    if not Path('.env').exists():
        return env

    with open('.env') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, val = line.split('=', 1)
                env[key] = val
    return env


def read_roster(vault_path: str) -> tuple:
    """Read AGENT_ROSTER.md for enabled agents."""
    roster_path = Path(vault_path) / "AGENT_ROSTER.md"
    if not roster_path.exists():
        return [], {}

    text = roster_path.read_text()
    enabled = []
    roster = {}

    for line in text.splitlines():
        if '|' in line and 'active' in line:
            parts = [p.strip() for p in line.split('|')]
            if len(parts) >= 5 and parts[0] not in ('', 'Agent'):
                name = parts[1]
                role = parts[2]
                provider = parts[3]
                model = parts[4]
                enabled.append(role)
                roster[role] = {
                    'name': name,
                    'provider': provider,
                    'model': model
                }

    return enabled, roster


def main():
    vault_path = os.environ.get('VAULT_PATH', str(Path.home() / 'Documents' / 'Home-Brain'))
    if len(sys.argv) > 1:
        vault_path = sys.argv[1]

    print(f"Reading vault at: {vault_path}")

    memories = read_memories(vault_path)
    env = read_env()
    enabled, roster = read_roster(vault_path)

    # Build providers dict from env
    providers = {}
    if env.get('ANTHROPIC_API_KEY'):
        providers['anthropic'] = {'api_key': env['ANTHROPIC_API_KEY']}
    if env.get('GOOGLE_API_KEY'):
        providers['google'] = {'api_key': env['GOOGLE_API_KEY']}
    if env.get('KIMI_API_KEY'):
        providers['kimi'] = {'api_key': env['KIMI_API_KEY']}
    if env.get('OPENROUTER_API_KEY'):
        providers['openrouter'] = {'api_key': env['OPENROUTER_API_KEY']}
    if env.get('OPENAI_API_KEY'):
        providers['openai'] = {'api_key': env['OPENAI_API_KEY']}

    output = {
        'version': '1.0',
        'date': datetime.now().strftime('%Y-%m-%d'),
        'user': {
            'name': memories.get('name', 'User'),
            'email': memories.get('email', ''),
            'timezone': memories.get('timezone', 'UTC'),
        },
        'paths': {
            'vault': vault_path,
            'hermes_home': env.get('HERMES_HOME', str(Path.home() / '.hermes')),
        },
        'agents': {
            'enabled': enabled or ['orchestrator', 'coder'],
            'roster': roster,
        },
        'providers': providers,
        'delivery': {
            'platform': 'local-only',
        },
        'projects': {
            'health': (Path(vault_path) / 'projects' / 'health').exists(),
            'finance': (Path(vault_path) / 'projects' / 'finance').exists(),
        },
        'locale': {
            'currency_symbol': '$',
            'country_code': 'Generic',
            'household_mode': memories.get('household', 'single'),
        },
        'install': {
            'mode': 'gui',
            'auto_start': 'manual',
        },
    }

    out_path = 'setup_answers.yaml'
    with open(out_path, 'w') as f:
        yaml.dump(output, f, default_flow_style=False, sort_keys=False)

    print(f"Wrote {out_path}")
    print(f"  Enabled agents: {', '.join(output['agents']['enabled'])}")
    print(f"  Providers: {', '.join(providers.keys())}")


if __name__ == '__main__':
    main()
