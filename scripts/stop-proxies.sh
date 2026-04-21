#!/usr/bin/env bash
# Stop all llm-cli-proxy screen sessions

set -euo pipefail

SESSIONS=$(screen -ls 2>/dev/null | grep -oE 'proxy-\w+' || true)

if [[ -z "$SESSIONS" ]]; then
    echo "No proxy sessions found."
    exit 0
fi

for session in $SESSIONS; do
    echo "Stopping $session..."
    screen -S "$session" -X quit 2>/dev/null || true
done

echo "All proxy sessions stopped."
