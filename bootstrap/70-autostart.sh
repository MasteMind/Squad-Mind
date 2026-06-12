#!/usr/bin/env bash
# Stage 7: Enable Auto-Start (launchd, systemd, screen, or manual)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 7

info "=== Stage 7: Auto-Start Configuration ==="

require_answers_v2 "setup_answers.yaml"

detect_platform

HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"
export HERMES_HOME

AUTO_START=$(read_yaml_key setup_answers.yaml "install.auto_start" || echo "manual")

# launchd is the macOS default when the interview asked for auto-start
# but a Linux-only mode was recorded.
if [[ "$PLATFORM" == "macOS" && "$AUTO_START" == "systemd" ]]; then
    warn "systemd requested on macOS — using launchd instead"
    AUTO_START="launchd"
fi

info "Auto-start preference: $AUTO_START"

# Shared render inputs (defaults match the live reference deployment)
NODE_BIN="${NODE_BIN:-$(command -v node || echo /usr/local/bin/node)}"
PROXY_DIST="${PROXY_DIST:-$HERMES_HOME/llm-cli-proxy-link/dist/index.js}"
HERMES_VENV="${HERMES_VENV:-$HERMES_HOME/hermes-agent/venv}"

# ------------------------------------------------------------------
# Agent table from the rendered bot YAMLs (stage 40 output is the
# authoritative post-render truth: id, cli, port, workspace, model)
# ------------------------------------------------------------------
AGENTS_TSV=$(mktemp)
export AGENTS_TSV

python3 << 'PYEOF'
import glob
import os
import yaml

hermes_home = os.environ['HERMES_HOME']
# '|'-separated rows: bash `read` with whitespace IFS collapses empty
# fields (talaria has no port/cli), so a non-whitespace separator is used.
rows = []
for path in sorted(glob.glob(os.path.join(hermes_home, 'bots', '*.yaml'))):
    with open(path) as f:
        bot = yaml.safe_load(f)
    agent_id = bot.get('id', os.path.splitext(os.path.basename(path))[0])
    cli = bot.get('cli', '')
    port = str((bot.get('proxy') or {}).get('port', '') or '')
    workspace = bot.get('workspace', '')
    model = str(bot.get('model', ''))
    rows.append('|'.join([agent_id, cli, port, workspace, model]))

with open(os.environ['AGENTS_TSV'], 'w') as f:
    f.write('\n'.join(rows) + '\n')
PYEOF

if [[ ! -s "$AGENTS_TSV" ]]; then
    warn "No rendered bot YAMLs found in $HERMES_HOME/bots — run stage 40 first"
fi

# ------------------------------------------------------------------
# launchd (macOS)
# ------------------------------------------------------------------
if [[ "$AUTO_START" == "launchd" ]]; then
    if [[ "$PLATFORM" != "macOS" ]] || ! command -v launchctl &>/dev/null; then
        warn "launchd auto-start requires macOS with launchctl. Skipping."
    else
        info "Configuring launchd agents..."

        LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENTS_DIR" "$HERMES_HOME/logs"
        UID_NUM=$(id -u)

        PROXY_TMPL="templates/runtime/launchd/ai.hermes.proxy.plist.tmpl"
        GATEWAY_TMPL="templates/runtime/launchd/ai.hermes.gateway.plist.tmpl"
        require_file "$PROXY_TMPL"
        require_file "$GATEWAY_TMPL"

        # One proxy per proxy-enabled agent (talaria has no port → skipped)
        while IFS='|' read -r agent_id cli port workspace model; do
            [[ -z "$port" ]] && continue
            plist="$LAUNCH_AGENTS_DIR/ai.hermes.proxy-${agent_id}.plist"
            render_template "$PROXY_TMPL" "$plist" \
                "AGENT_ID=$agent_id" \
                "AGENT_CLI=$cli" \
                "AGENT_PORT=$port" \
                "AGENT_WORKSPACE=$workspace" \
                "AGENT_MODEL=$model" \
                "NODE_BIN=$NODE_BIN" \
                "PROXY_DIST=$PROXY_DIST" \
                "HERMES_HOME=$HERMES_HOME" \
                "HOME=$HOME"
            launchctl bootstrap "gui/$UID_NUM" "$plist" 2>/dev/null \
                || info "ai.hermes.proxy-${agent_id} already bootstrapped"
            info "launchd proxy installed: $plist"
        done < "$AGENTS_TSV"

        # Root gateway (orchestrator): Label ai.hermes.gateway, no --profile args
        ROOT_PLIST="$LAUNCH_AGENTS_DIR/ai.hermes.gateway.plist"
        render_template "$GATEWAY_TMPL" "$ROOT_PLIST" \
            "AGENT_ID=__ROOT__" \
            "HERMES_HOME=$HERMES_HOME" \
            "HERMES_VENV=$HERMES_VENV" \
            "HOME=$HOME"
        sed_inplace \
            -e 's|ai\.hermes\.gateway-__ROOT__|ai.hermes.gateway|' \
            -e '/<string>--profile<\/string>/d' \
            -e '/<string>__ROOT__<\/string>/d' \
            "$ROOT_PLIST"
        launchctl bootstrap "gui/$UID_NUM" "$ROOT_PLIST" 2>/dev/null \
            || info "ai.hermes.gateway already bootstrapped"
        info "launchd gateway installed: $ROOT_PLIST"

        # One gateway per non-orchestrator profile
        while IFS='|' read -r agent_id cli port workspace model; do
            [[ "$agent_id" == "hermes" ]] && continue
            profile_home="$HERMES_HOME/profiles/$agent_id"
            mkdir -p "$profile_home/logs"
            plist="$LAUNCH_AGENTS_DIR/ai.hermes.gateway-${agent_id}.plist"
            render_template "$GATEWAY_TMPL" "$plist" \
                "AGENT_ID=$agent_id" \
                "HERMES_HOME=$profile_home" \
                "HERMES_VENV=$HERMES_VENV" \
                "HOME=$HOME"
            launchctl bootstrap "gui/$UID_NUM" "$plist" 2>/dev/null \
                || info "ai.hermes.gateway-${agent_id} already bootstrapped"
            info "launchd gateway installed: $plist"
        done < "$AGENTS_TSV"
    fi
fi

# ------------------------------------------------------------------
# systemd (Linux)
# ------------------------------------------------------------------
if [[ "$AUTO_START" == "systemd" ]]; then
    info "Configuring systemd user services..."

    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR" "$HERMES_HOME/proxies"

    PROXY_UNIT_TMPL="templates/runtime/systemd/proxy@.service.tmpl"
    GATEWAY_UNIT_TMPL="templates/runtime/systemd/hermes-gateway@.service.tmpl"
    require_file "$PROXY_UNIT_TMPL"
    require_file "$GATEWAY_UNIT_TMPL"

    render_template "$PROXY_UNIT_TMPL" "$SYSTEMD_USER_DIR/proxy@.service" \
        "HERMES_HOME=$HERMES_HOME" \
        "NODE_BIN=$NODE_BIN" \
        "PROXY_DIST=$PROXY_DIST"
    render_template "$GATEWAY_UNIT_TMPL" "$SYSTEMD_USER_DIR/hermes-gateway@.service" \
        "HERMES_HOME=$HERMES_HOME" \
        "HERMES_VENV=$HERMES_VENV"
    info "Rendered proxy@.service and hermes-gateway@.service"

    # Per-agent environment files consumed by proxy@%i
    while IFS='|' read -r agent_id cli port workspace model; do
        [[ -z "$port" ]] && continue
        cat > "$HERMES_HOME/proxies/${agent_id}.env" << EOF
AGENT_CLI=$cli
AGENT_PORT=$port
AGENT_WORKSPACE=$workspace
AGENT_MODEL=$model
EOF
        chmod 600 "$HERMES_HOME/proxies/${agent_id}.env"
    done < "$AGENTS_TSV"

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || warn "systemctl daemon-reload failed"

        while IFS='|' read -r agent_id cli port workspace model; do
            if [[ -n "$port" ]]; then
                systemctl --user enable "proxy@${agent_id}" 2>/dev/null \
                    || warn "Failed to enable proxy@${agent_id}"
            fi
            if [[ "$agent_id" != "hermes" ]]; then
                mkdir -p "$HERMES_HOME/profiles/$agent_id"
                systemctl --user enable "hermes-gateway@${agent_id}" 2>/dev/null \
                    || warn "Failed to enable hermes-gateway@${agent_id}"
            fi
        done < "$AGENTS_TSV"

        info "systemd user services enabled"
    else
        warn "systemctl not found. systemd auto-start cannot be configured."
    fi
fi

# ------------------------------------------------------------------
# screen wrapper (fallback)
# ------------------------------------------------------------------
if [[ "$AUTO_START" == "screen" ]]; then
    info "Creating screen wrapper script..."

    WRAPPER="$HERMES_HOME/hermes-start.sh"
    cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
# Squad-Mind startup wrapper for screen/tmux sessions

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
VAULT_PATH="${VAULT_PATH:-$HOME/Documents/Home-Brain}"

echo "=== Starting Squad-Mind agents ==="

# Start orchestrator in screen
if ! screen -ls | grep -q "hermes-orchestrator"; then
    screen -dmS hermes-orchestrator bash -c "cd '$HERMES_HOME' && echo 'Hermes orchestrator placeholder'; exec bash"
    echo "Started hermes-orchestrator in screen"
fi

echo "Done. Use 'screen -ls' to list sessions."
EOF
    chmod +x "$WRAPPER"
    info "Created $WRAPPER"
    info "Run it manually after login, or add to your shell profile."
fi

# ------------------------------------------------------------------
# manual: nothing to do
# ------------------------------------------------------------------
if [[ "$AUTO_START" == "manual" ]]; then
    info "Auto-start is manual. No services configured."
fi

rm -f "$AGENTS_TSV"

set_step 7
info "=== Stage 7 complete ==="
