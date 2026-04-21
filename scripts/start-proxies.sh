#!/usr/bin/env bash
# Start llm-cli-proxy instances for enabled CLI providers
# Usage: ./scripts/start-proxies.sh [setup_answers.yaml]

set -euo pipefail

CONFIG="${1:-setup_answers.yaml}"

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: $CONFIG not found. Run bootstrap interview first."
    exit 1
fi

# Read proxy config from setup_answers.yaml
PROVIDER_MODE=$(python3 -c "
import yaml
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
print(data.get('providers', {}).get('mode', 'api-keys'))
")

if [[ "$PROVIDER_MODE" != "cli-proxy" ]]; then
    echo "Provider mode is '$PROVIDER_MODE'. No proxies to start."
    exit 0
fi

# Check llm-cli-proxy is installed
if ! command -v llm-cli-proxy >/dev/null 2>&1; then
    echo "Error: llm-cli-proxy not found."
    echo "Install: npm install -g llm-cli-proxy"
    exit 1
fi

# Parse enabled proxies and ports
python3 << 'PYEOF'
import yaml, subprocess, sys, os

with open("""$CONFIG""") as f:
    config = yaml.safe_load(f)

cli_proxy = config.get('providers', {}).get('cli_proxy', {})
enabled = cli_proxy.get('enabled', [])
ports = cli_proxy.get('ports', {})

# Default port mappings
port_defaults = {
    'claude': 3456,
    'gemini': 3457,
}

workspace = config.get('paths', {}).get('vault', os.path.expanduser('~/Documents/Home-Brain'))

for provider in enabled:
    port = ports.get(provider, port_defaults.get(provider, 3456))
    session_name = f"proxy-{provider}"

    # Check if already running
    result = subprocess.run(
        ['screen', '-ls'],
        capture_output=True, text=True
    )
    if session_name in result.stdout:
        print(f"[{provider}] Screen session '{session_name}' already exists. Skipping.")
        continue

    cmd = f"llm-cli-proxy --provider {provider} --port {port} --workspace {workspace}"
    screen_cmd = ['screen', '-dmS', session_name, 'bash', '-c', cmd]

    print(f"[{provider}] Starting proxy on port {port}...")
    subprocess.run(screen_cmd, check=True)
    print(f"[{provider}] Started in screen session: {session_name}")

print("\nAll proxies started. Verify with: screen -ls")
print("View logs: screen -r <session-name>")
print("Stop all:  ./scripts/stop-proxies.sh")
PYEOF
