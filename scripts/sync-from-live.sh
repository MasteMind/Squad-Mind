#!/usr/bin/env bash
# Thin wrapper around sync_from_live.py — see that file for usage.
set -euo pipefail
# Prefer the first python3 on PATH that has PyYAML (Homebrew python often lacks it;
# macOS system python ships with it).
for py in python3 /usr/bin/python3; do
  if "$py" -c 'import yaml' >/dev/null 2>&1; then
    exec "$py" "$(dirname "$0")/sync_from_live.py" "$@"
  fi
done
echo "sync-from-live.sh: no python3 with PyYAML found (pip install pyyaml)" >&2
exit 1
