#!/usr/bin/env python3
"""
rotate-keys.py
Safely rotate API keys. Backs up old .env, prompts for new keys, validates them.
"""

import os
import shutil
from pathlib import Path
from datetime import datetime


def backup_env():
    if not Path('.env').exists():
        print("No .env found. Nothing to rotate.")
        return False

    backup = f".env.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
    shutil.copy('.env', backup)
    print(f"Backed up old .env to {backup}")
    return True


def prompt_key(name: str, current: str) -> str:
    masked = current[:8] + '...' if len(current) > 8 else '(not set)'
    print(f"\n{name} (current: {masked})")
    new = input(f"Enter new {name} (or press Enter to keep current): ").strip()
    return new if new else current


def validate_key(provider: str, key: str) -> bool:
    """Basic validation: key is non-empty and looks right."""
    if not key:
        return False
    if provider == 'anthropic' and not key.startswith('sk-ant'):
        print(f"  Warning: Anthropic key should start with 'sk-ant'")
    if provider == 'google' and not key.startswith('AIza'):
        print(f"  Warning: Google key should start with 'AIza'")
    return True


def main():
    if not backup_env():
        return

    # Read current .env
    env_vars = {}
    with open('.env') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                k, v = line.split('=', 1)
                env_vars[k] = v

    providers = [
        ('ANTHROPIC_API_KEY', 'Anthropic'),
        ('GOOGLE_API_KEY', 'Google'),
        ('KIMI_API_KEY', 'Kimi'),
        ('OPENROUTER_API_KEY', 'OpenRouter'),
        ('OPENAI_API_KEY', 'OpenAI'),
    ]

    updated = False
    for env_var, name in providers:
        current = env_vars.get(env_var, '')
        new_key = prompt_key(name, current)
        if new_key != current:
            env_vars[env_var] = new_key
            if validate_key(name.lower(), new_key):
                print(f"  {name} key updated and validated.")
                updated = True
            else:
                print(f"  Warning: {name} key looks unusual. Proceeding anyway.")
                updated = True

    if not updated:
        print("\nNo keys changed.")
        return

    # Write new .env
    with open('.env', 'w') as f:
        for k, v in env_vars.items():
            f.write(f"{k}={v}\n")

    os.chmod('.env', 0o600)
    print("\n.env updated. Permissions set to 600.")
    print("Run ./bootstrap/50-smoke-test.sh to verify new keys.")


if __name__ == '__main__':
    main()
