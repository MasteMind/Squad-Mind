#!/usr/bin/env bash
# Thin wrapper around sync_from_live.py — see that file for usage.
set -euo pipefail
exec python3 "$(dirname "$0")/sync_from_live.py" "$@"
