#!/usr/bin/env python3
"""
reverse-interview.py
Reads the current vault + .env and emits an updated setup_answers.yaml
(schema 2.0). Useful when you want to regenerate the interview from an
edited config.
"""

import os
import re
import yaml
import sys
from pathlib import Path
from datetime import datetime

SQUAD_AGENTS = ('hermes', 'hephaestus', 'clio', 'talaria')


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
    """Parse brain/Memories.md for user + team info."""
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

    m = re.search(r'^- Team:\s*(.+)$', text, re.MULTILINE)
    if m:
        result['team_name'] = m.group(1).strip()

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


def read_roster(vault_path: str) -> dict:
    """Read brain/AGENT_ROSTER.md (stage-40 output) for per-agent bindings.

    Row shape: | Agent | Role | CLI | Model | Port | Workspace | Status |
    Returns {agent_id: {cli, model, port}}.
    """
    roster_path = Path(vault_path) / "brain" / "AGENT_ROSTER.md"
    if not roster_path.exists():
        return {}

    text = roster_path.read_text()
    roster = {}

    for line in text.splitlines():
        if '|' not in line or '| active |' not in line:
            continue
        parts = [p.strip() for p in line.split('|')]
        if len(parts) < 8 or parts[1] in ('', 'Agent'):
            continue
        name, _role, cli, model, port = parts[1], parts[2], parts[3], parts[4], parts[5]
        agent_id = name.lower()
        if agent_id not in SQUAD_AGENTS:
            continue
        entry = {'cli': cli, 'model': model}
        if port and port not in ('—', '-'):
            try:
                entry['port'] = int(port)
            except ValueError:
                pass
        roster[agent_id] = entry

    return roster


def main():
    vault_path = os.environ.get('VAULT_PATH', str(Path.home() / 'Documents' / 'Home-Brain'))
    if len(sys.argv) > 1:
        vault_path = sys.argv[1]

    print(f"Reading vault at: {vault_path}")

    memories = read_memories(vault_path)
    env = read_env()
    roster = read_roster(vault_path)

    # Build providers dict from env
    providers = {}
    if env.get('ANTHROPIC_API_KEY'):
        providers['anthropic'] = {'api_key': env['ANTHROPIC_API_KEY']}
    if env.get('GOOGLE_API_KEY'):
        providers['google'] = {'api_key': env['GOOGLE_API_KEY']}
    if env.get('OPENAI_API_KEY'):
        providers['openai'] = {'api_key': env['OPENAI_API_KEY']}
    providers['mode'] = 'cli-proxy' if env.get('PROXY_MODE', '').lower() == 'true' else 'api-keys'

    talaria_enabled = 'talaria' in roster

    output = {
        'version': '2.0',
        'date': datetime.now().strftime('%Y-%m-%d'),
        'user': {
            'name': memories.get('name', 'User'),
            'email': memories.get('email', ''),
            'timezone': memories.get('timezone', 'UTC'),
        },
        'team': {
            'name': memories.get('team_name', 'My Team'),
        },
        'paths': {
            'vault': vault_path,
            'hermes_home': env.get('HERMES_HOME', str(Path.home() / '.hermes')),
        },
        'providers': providers,
        'agents': {
            'roster': roster,
            'talaria_enabled': talaria_enabled,
        },
        'lab': {
            'default_profile': 'auto',
        },
        'projects': {
            'lab': (Path(vault_path) / 'projects' / 'agent-distribution-lab').exists(),
        },
        'delivery': {
            'platform': 'local-only',
        },
        'install': {
            'mode': 'gui',
            'auto_start': 'manual',
        },
    }

    if talaria_enabled:
        output['ollama'] = {
            'base_url': env.get('OLLAMA_BASE_URL', 'http://localhost:11434'),
        }

    out_path = 'setup_answers.yaml'
    with open(out_path, 'w') as f:
        yaml.dump(output, f, default_flow_style=False, sort_keys=False)

    print(f"Wrote {out_path}")
    print(f"  Agents: {', '.join(roster.keys()) or '(roster not found)'}")
    print(f"  Provider mode: {providers['mode']}")


if __name__ == '__main__':
    main()
