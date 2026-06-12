#!/usr/bin/env python3
"""
rotate-keys.py
Safely rotate API keys. Backs up old .env, prompts for new keys, validates them.

Target file resolution order:
  1. --env-file PATH (explicit)
  2. $HERMES_HOME/.env (if it exists)
  3. /srv/squad/secrets/.env (server layout, if it exists)
  4. ./.env (legacy local default)

Permissions and ownership of the target file are preserved on rewrite
(the server file is root:hermes 640 and must stay that way).
"""

import argparse
import os
import shutil
from pathlib import Path
from datetime import datetime


def resolve_env_file(flag_value):
    if flag_value:
        return Path(flag_value).expanduser()
    hermes_home = os.environ.get('HERMES_HOME', '').strip()
    if hermes_home:
        candidate = Path(hermes_home).expanduser() / '.env'
        if candidate.exists():
            return candidate
    server_env = Path('/srv/squad/secrets/.env')
    if server_env.exists():
        return server_env
    return Path('.env')


def backup_env(env_path: Path):
    if not env_path.exists():
        print(f"No {env_path} found. Nothing to rotate.")
        return False

    backup = env_path.with_name(
        f"{env_path.name}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
    )
    shutil.copy(env_path, backup)  # copies mode bits too
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
    parser = argparse.ArgumentParser(description="Rotate API keys in a .env file.")
    parser.add_argument(
        '--env-file',
        help="Path to the .env file (default: $HERMES_HOME/.env, "
             "then /srv/squad/secrets/.env, then ./.env)",
    )
    args = parser.parse_args()
    env_path = resolve_env_file(args.env_file)
    print(f"Rotating keys in: {env_path}")

    if not backup_env(env_path):
        return

    # Capture perms/ownership so the rewrite preserves them
    # (root:hermes 640 on the server; 600 locally).
    st = env_path.stat()

    # Read current .env
    env_vars = {}
    with open(env_path) as f:
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

    # Write new .env in place (truncating keeps the inode, so owner/group survive)
    with open(env_path, 'w') as f:
        for k, v in env_vars.items():
            f.write(f"{k}={v}\n")

    os.chmod(env_path, st.st_mode & 0o777)
    try:
        os.chown(env_path, st.st_uid, st.st_gid)
    except PermissionError:
        pass  # non-root caller rotating a file it owns — ownership unchanged
    print(f"\n{env_path} updated. Permissions preserved ({oct(st.st_mode & 0o777)}).")
    print("Run ./bootstrap/50-smoke-test.sh to verify new keys.")


if __name__ == '__main__':
    main()
