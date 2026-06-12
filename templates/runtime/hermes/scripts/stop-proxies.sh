#!/usr/bin/env bash
# stop-proxies.sh — stop the llm-cli-proxy instances by unloading their
# launchd jobs. This stops them AND prevents auto-restart until reloaded
# (via start-proxies.sh or a fresh login). Belt-and-braces: quits legacy
# screen sessions and kills orphan proxy processes on the agents' ports.
#
# Usage mirrors start-proxies.sh:
#   stop-proxies.sh [agent ...]   # default: hermes hephaestus clio
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
  if launchctl list 2>/dev/null | grep -q "$label"; then
    launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
    echo "[$name] unloaded"
  else
    echo "[$name] not loaded"
  fi
done

# Belt-and-braces: legacy screen sessions from before the launchd migration
for name in "${AGENTS[@]}"; do
  session="proxy-$name"
  if screen -ls 2>/dev/null | grep -q "\.${session}\b"; then
    screen -S "$session" -X quit 2>/dev/null || true
    echo "[$name] stale screen quit"
  fi
done

# Kill any orphan llm-cli-proxy / node-running-dist procs on the agents' ports
for name in "${AGENTS[@]}"; do
  port=$(awk '$1 == "port:" {print $2; exit}' "$HERMES_HOME/bots/$name.yaml" 2>/dev/null || true)
  [[ -z "${port:-}" ]] && continue
  pid=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)
  if [[ -n "$pid" ]]; then
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "")
    if [[ "$cmd" == *"llm-cli-proxy"* ]] || [[ "$cmd" == *"dist/index.js"* ]]; then
      kill -9 "$pid" 2>/dev/null && echo "[:$port] killed orphan PID $pid"
    fi
  fi
done

sleep 1
echo ""
echo "=== listeners after stop ==="
found=0
for name in "${AGENTS[@]}"; do
  port=$(awk '$1 == "port:" {print $2; exit}' "$HERMES_HOME/bots/$name.yaml" 2>/dev/null || true)
  [[ -z "${port:-}" ]] && continue
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null; then
    found=1
  fi
done
[[ $found -eq 0 ]] && echo "(no listeners on proxy ports)"
