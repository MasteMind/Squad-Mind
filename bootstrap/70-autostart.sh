#!/usr/bin/env bash
# Stage 7: Enable Auto-Start (systemd, screen, or manual)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 7

info "=== Stage 7: Auto-Start Configuration ==="

require_file "setup_answers.yaml"

HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

AUTO_START=$(read_yaml_key setup_answers.yaml "install.auto_start" || echo "manual")
PROVIDER_MODE=$(read_yaml_key setup_answers.yaml "providers.mode" || echo "api-keys")

info "Auto-start preference: $AUTO_START"

# ------------------------------------------------------------------
# systemd
# ------------------------------------------------------------------
if [[ "$AUTO_START" == "systemd" ]]; then
    info "Configuring systemd user services..."

    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"

    # Orchestrator service
    if [[ -f "templates/systemd/hermes-orchestrator.service" ]]; then
        cp "templates/systemd/hermes-orchestrator.service" \
            "$SYSTEMD_USER_DIR/hermes-orchestrator.service"
    else
        cat > "$SYSTEMD_USER_DIR/hermes-orchestrator.service" << EOF
[Unit]
Description=Squad-Mind Hermes Orchestrator
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.hermes/bin/hermes-orchestrator
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
    fi
    info "Created hermes-orchestrator.service"

    # Proxy services (if cli-proxy mode)
    if [[ "$PROVIDER_MODE" == "cli-proxy" ]]; then
        CLI_PROXY_ENABLED=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
for p in data.get('providers', {}).get('cli_proxy', {}).get('enabled', []):
    print(p)
" 2>/dev/null || true)

        if echo "$CLI_PROXY_ENABLED" | grep -q "claude"; then
            if [[ -f "templates/systemd/proxy-claude.service" ]]; then
                cp "templates/systemd/proxy-claude.service" \
                    "$SYSTEMD_USER_DIR/hermes-proxy-claude.service"
            else
                cat > "$SYSTEMD_USER_DIR/hermes-proxy-claude.service" << EOF
[Unit]
Description=Squad-Mind Claude Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.npm-global/bin/llm-cli-proxy --provider claude --port 3456 --workspace $VAULT_PATH
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
            fi
            info "Created hermes-proxy-claude.service"
        fi

        if echo "$CLI_PROXY_ENABLED" | grep -q "gemini"; then
            if [[ -f "templates/systemd/proxy-gemini.service" ]]; then
                cp "templates/systemd/proxy-gemini.service" \
                    "$SYSTEMD_USER_DIR/hermes-proxy-gemini.service"
            else
                cat > "$SYSTEMD_USER_DIR/hermes-proxy-gemini.service" << EOF
[Unit]
Description=Squad-Mind Gemini Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.npm-global/bin/llm-cli-proxy --provider gemini --port 3457 --workspace $VAULT_PATH
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
            fi
            info "Created hermes-proxy-gemini.service"
        fi
    fi

    # Reload and enable
    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || warn "systemctl daemon-reload failed"
        systemctl --user enable hermes-orchestrator 2>/dev/null || warn "Failed to enable hermes-orchestrator"

        if [[ "$PROVIDER_MODE" == "cli-proxy" ]]; then
            if [[ -f "$SYSTEMD_USER_DIR/hermes-proxy-claude.service" ]]; then
                systemctl --user enable hermes-proxy-claude 2>/dev/null || true
            fi
            if [[ -f "$SYSTEMD_USER_DIR/hermes-proxy-gemini.service" ]]; then
                systemctl --user enable hermes-proxy-gemini 2>/dev/null || true
            fi
        fi

        info "systemd user services enabled"
    else
        warn "systemctl not found. systemd auto-start cannot be configured."
    fi
fi

# ------------------------------------------------------------------
# screen wrapper
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

set_step 7
info "=== Stage 7 complete ==="
