#!/usr/bin/env bash
# start-proxies.sh — (re)start the launchd-managed llm-cli-proxy instances.
#
# Proxies are launchd-managed via plists at:
#   ~/Library/LaunchAgents/ai.hermes.proxy-<agent>.plist
# (rendered from templates/runtime/launchd/ai.hermes.proxy.plist.tmpl).
# Those plists run at login (RunAtLoad=true) and auto-restart on crash
# (KeepAlive.SuccessfulExit=false). This script is a manual override that
# (re)starts each via `launchctl bootstrap` / `launchctl kickstart`.
# The junior agent (Ollama runtime) does NOT use a proxy.
#
# Usage:
#   start-proxies.sh [agent ...]        # explicit agent list
#   HERMES_PROXY_AGENTS="a b" start-proxies.sh
#   start-proxies.sh                    # default: hermes hephaestus clio
#
# Not a template: $VAR below is runtime shell expansion, on purpose.

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

AGENTS=("$@")
if [[ ${#AGENTS[@]} -eq 0 ]]; then
  # shellcheck disable=SC2206  # word-splitting the list is intended
  AGENTS=(${HERMES_PROXY_AGENTS:-hermes hephaestus clio})
fi

UID_NUM=$(id -u)

for name in "${AGENTS[@]}"; do
  label="ai.hermes.proxy-$name"
  # bootstrap (load) if not already loaded
  if ! launchctl list 2>/dev/null | grep -q "$label"; then
    launchctl bootstrap "gui/$UID_NUM" "$HOME/Library/LaunchAgents/$label.plist" 2>/dev/null || true
    echo "[$name] loaded"
  else
    launchctl kickstart -k "gui/$UID_NUM/$label" 2>/dev/null || true
    echo "[$name] kickstarted"
  fi
done

sleep 4

echo ""
echo "=== health ==="
for name in "${AGENTS[@]}"; do
  port=$(awk '$1 == "port:" {print $2; exit}' "$HERMES_HOME/bots/$name.yaml" 2>/dev/null || true)
  if [[ -z "${port:-}" ]]; then
    echo "[$name] no proxy port in $HERMES_HOME/bots/$name.yaml (skipped)"
    continue
  fi
  status=$(curl -s --max-time 3 "http://localhost:$port/health" 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d['status'], '—', d['provider'], '—', d['model'])" 2>/dev/null) \
    || status="DOWN"
  echo "[$name] port $port: $status"
done
