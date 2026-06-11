#!/usr/bin/env bash
# server-install.sh — idempotent Squad-Mind installer for a shared Ubuntu VM.
#
# One team per VM: systemd SYSTEM units, single `hermes` service user,
# /srv/squad/{brain,hermes,archive,secrets} layout. Wraps the bootstrap
# stages headless (the tests/bootstrap-integration.sh --local pattern:
# pre-written setup_answers + env overrides), then installs the units from
# deploy/systemd/.
#
# Licensing: CLI proxies are dev/laptop mode only. providers.mode is
# api-keys on servers (Claude Max / Codex / Gemini Advanced are per-human
# consumer subscriptions); keys go in /srv/squad/secrets/.env.
#
# Usage (as root, from a Squad-Mind checkout):
#   deploy/server-install.sh [--team-name NAME] [--admin-name NAME]
#       [--admin-email EMAIL] [--timezone TZ] [--brain-git-url URL]
#       [--talaria-local] [--cli-proxy-dev]
# Every flag also reads from env: TEAM_NAME, ADMIN_NAME, ADMIN_EMAIL,
# SQUAD_TIMEZONE, BRAIN_GIT_URL, TALARIA_LOCAL=1, CLI_PROXY_DEV=1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQUAD_MIND_DIR="$(dirname "$SCRIPT_DIR")"

SQUAD_ROOT="/srv/squad"
SQUAD_USER="hermes"
SQUAD_HOME="$SQUAD_ROOT/hermes"
VAULT_PATH="$SQUAD_ROOT/brain"
SECRETS_DIR="$SQUAD_ROOT/secrets"
CHECKOUT="$SQUAD_ROOT/squad-mind"
STATE_FILE_PATH="$SQUAD_HOME/hermes-setup.state"
VENV="$SQUAD_HOME/venv"

TEAM_NAME="${TEAM_NAME:-My Team}"
ADMIN_NAME="${ADMIN_NAME:-Squad Admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
SQUAD_TIMEZONE="${SQUAD_TIMEZONE:-UTC}"
BRAIN_GIT_URL="${BRAIN_GIT_URL:-}"
TALARIA_LOCAL="${TALARIA_LOCAL:-0}"
CLI_PROXY_DEV="${CLI_PROXY_DEV:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team-name)     TEAM_NAME="$2"; shift 2 ;;
        --admin-name)    ADMIN_NAME="$2"; shift 2 ;;
        --admin-email)   ADMIN_EMAIL="$2"; shift 2 ;;
        --timezone)      SQUAD_TIMEZONE="$2"; shift 2 ;;
        --brain-git-url) BRAIN_GIT_URL="$2"; shift 2 ;;
        --talaria-local) TALARIA_LOCAL=1; shift ;;
        --cli-proxy-dev) CLI_PROXY_DEV=1; shift ;;
        -h|--help)       grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

log() { echo "[server-install] $*"; }

# ------------------------------------------------------------------
# 1. Root + OS check
# ------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
    echo "server-install.sh must run as root (it creates the service user," >&2
    echo "installs packages, and writes /etc/systemd/system)." >&2
    exit 1
fi

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
        ubuntu:*|debian:*|*:*debian*) log "OS: ${PRETTY_NAME:-unknown} — OK" ;;
        *) log "WARNING: untested OS (${PRETTY_NAME:-unknown}). This installer targets Ubuntu/Debian; continuing anyway." ;;
    esac
else
    log "WARNING: /etc/os-release not found — cannot verify OS. Continuing."
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl not found — a systemd host is required." >&2
    exit 1
fi

# ------------------------------------------------------------------
# 2. Service user + /srv/squad layout
# ------------------------------------------------------------------
mkdir -p "$SQUAD_ROOT"
if ! getent passwd "$SQUAD_USER" >/dev/null; then
    useradd --system --home-dir "$SQUAD_HOME" --create-home \
        --shell /usr/sbin/nologin "$SQUAD_USER"
    log "Created system user $SQUAD_USER"
else
    log "System user $SQUAD_USER exists"
fi

mkdir -p "$VAULT_PATH" "$SQUAD_HOME" "$SQUAD_ROOT/archive" "$SECRETS_DIR"
chown "$SQUAD_USER:$SQUAD_USER" "$VAULT_PATH" "$SQUAD_HOME" "$SQUAD_ROOT/archive"
chown "root:$SQUAD_USER" "$SECRETS_DIR"
chmod 750 "$SECRETS_DIR"
if [[ -f "$SECRETS_DIR/.env" ]]; then
    chown "root:$SQUAD_USER" "$SECRETS_DIR/.env"
    chmod 640 "$SECRETS_DIR/.env"
else
    # Stub so the gateway units' EnvironmentFile= resolves; keys still needed.
    cat > "$SECRETS_DIR/.env" << 'EOF'
# /srv/squad/secrets/.env — API keys for the squad (root:hermes 640).
# Fill from deploy/env/server.env.example. Servers use API keys / Vertex AI;
# CLI-subscription proxies are dev/laptop mode only (licensing).
EOF
    chown "root:$SQUAD_USER" "$SECRETS_DIR/.env"
    chmod 640 "$SECRETS_DIR/.env"
    log "Created stub $SECRETS_DIR/.env — fill it before starting the squad"
fi
log "/srv/squad layout ready"

# ------------------------------------------------------------------
# 3. Prereqs: apt packages, hermes venv (+ optional node / ollama)
# ------------------------------------------------------------------
PKGS=(python3 python3-yaml python3-venv git curl jq sqlite3 zstd)  # sqlite3+zstd: backup/audit timers
if [[ "$CLI_PROXY_DEV" == "1" ]]; then
    PKGS+=(nodejs npm)   # dev/laptop proxy mode only — never the server default
fi
if command -v apt-get >/dev/null 2>&1; then
    MISSING=()
    for pkg in "${PKGS[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
    done
    if [[ "${#MISSING[@]}" -gt 0 ]]; then
        log "Installing packages: ${MISSING[*]}"
        apt-get update -qq
        apt-get install -y -qq "${MISSING[@]}"
    else
        log "All apt prereqs present"
    fi
else
    log "WARNING: apt-get not found — ensure these are installed: ${PKGS[*]}"
fi

if [[ ! -x "$VENV/bin/python" ]]; then
    sudo -u "$SQUAD_USER" python3 -m venv "$VENV"
    log "Created venv at $VENV"
fi
if ! "$VENV/bin/python" -c 'import hermes_cli' >/dev/null 2>&1; then
    log "Installing hermes-agent into $VENV"
    sudo -u "$SQUAD_USER" "$VENV/bin/pip" install --quiet hermes-agent pyyaml
else
    log "hermes-agent already installed in $VENV"
fi

if [[ "$TALARIA_LOCAL" == "1" ]] && ! command -v ollama >/dev/null 2>&1; then
    log "Installing Ollama (TALARIA_LOCAL=1) — its installer creates ollama.service"
    curl -fsSL https://ollama.com/install.sh | sh
fi

# ------------------------------------------------------------------
# 4. Copy this checkout to /srv/squad/squad-mind (hermes-writable cwd
#    for the bootstrap stages; .env and answers land here, never in git)
# ------------------------------------------------------------------
mkdir -p "$CHECKOUT"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude .git --exclude hermes-setup.state \
        --exclude setup_answers.yaml --exclude .env --exclude bootstrap/log \
        "$SQUAD_MIND_DIR/" "$CHECKOUT/"
else
    (cd "$SQUAD_MIND_DIR" && tar -cf - --exclude .git --exclude hermes-setup.state \
        --exclude setup_answers.yaml --exclude .env --exclude bootstrap/log .) \
        | tar -xf - -C "$CHECKOUT"
fi
chown -R "$SQUAD_USER:$SQUAD_USER" "$CHECKOUT"
log "Squad-Mind checkout synced to $CHECKOUT"

# ------------------------------------------------------------------
# 5. Brain: clone/pull when a remote is given, else the bootstrap seeds it
# ------------------------------------------------------------------
SKIP_VAULT_SEED=0
if [[ -n "$BRAIN_GIT_URL" ]]; then
    if [[ -d "$VAULT_PATH/.git" ]]; then
        log "Brain repo exists — pulling"
        sudo -u "$SQUAD_USER" git -C "$VAULT_PATH" pull --rebase
    else
        log "Cloning brain from $BRAIN_GIT_URL"
        sudo -u "$SQUAD_USER" git clone "$BRAIN_GIT_URL" "$VAULT_PATH"
    fi
    if [[ -f "$VAULT_PATH/brain/hot.md" ]]; then
        SKIP_VAULT_SEED=1
        log "Cloned brain is already seeded — bootstrap stage 30 will be skipped"
    fi
fi

# ------------------------------------------------------------------
# 6. Headless bootstrap: render answers, run stages 00→50 (+80) as hermes
# ------------------------------------------------------------------
SQUAD_ANSWERS_SRC="$CHECKOUT/deploy/setup_answers.server.yaml" \
SQUAD_ANSWERS_DST="$CHECKOUT/setup_answers.yaml" \
TEAM_NAME="$TEAM_NAME" ADMIN_NAME="$ADMIN_NAME" ADMIN_EMAIL="$ADMIN_EMAIL" \
SQUAD_TIMEZONE="$SQUAD_TIMEZONE" TALARIA_LOCAL="$TALARIA_LOCAL" \
python3 << 'PYEOF'
import datetime
import os
import yaml

with open(os.environ['SQUAD_ANSWERS_SRC']) as f:
    text = f.read()

for marker, value in (
    ('__DATE__', datetime.date.today().isoformat()),
    ('__ADMIN_NAME__', os.environ['ADMIN_NAME']),
    ('__ADMIN_EMAIL__', os.environ['ADMIN_EMAIL']),
    ('__TIMEZONE__', os.environ['SQUAD_TIMEZONE']),
    ('__TEAM_NAME__', os.environ['TEAM_NAME']),
):
    text = text.replace(marker, value)

answers = yaml.safe_load(text)
if os.environ['TALARIA_LOCAL'] == '1':
    answers['agents']['talaria_enabled'] = True

assert str(answers['version']).startswith('2'), 'answers must be schema 2.0'
with open(os.environ['SQUAD_ANSWERS_DST'], 'w') as f:
    yaml.safe_dump(answers, f, default_flow_style=False, sort_keys=False)
print(f"Rendered {os.environ['SQUAD_ANSWERS_DST']}")
PYEOF
chown "$SQUAD_USER:$SQUAD_USER" "$CHECKOUT/setup_answers.yaml"
chmod 600 "$CHECKOUT/setup_answers.yaml"

run_stage() {
    local stage="$1"
    log "bootstrap/$stage (as $SQUAD_USER)"
    (cd "$CHECKOUT" && sudo -u "$SQUAD_USER" \
        HOME="$SQUAD_HOME" \
        STATE_FILE="$STATE_FILE_PATH" \
        LOG_DIR="$SQUAD_HOME/logs/bootstrap" \
        bash "bootstrap/$stage")
}

# Write the bootstrap state file directly (same format as lib/common.sh
# set_step) to mark stages this installer intentionally handles itself.
advance_state() {
    local step="$1"
    local current=0
    if [[ -f "$STATE_FILE_PATH" ]]; then
        current=$(grep '^STEP=' "$STATE_FILE_PATH" | cut -d= -f2 || echo 0)
    fi
    if [[ "$current" -lt "$step" ]]; then
        sudo -u "$SQUAD_USER" tee "$STATE_FILE_PATH" > /dev/null << EOF
STEP=$step
LAST_RUN=$(date -Iseconds)
PLATFORM=Linux
EOF
        log "State advanced to STEP=$step"
    fi
}

run_stage 00-prereqs.sh
run_stage 10-obsidian.sh          # headless mode: records the step, no GUI
run_stage 20-hermes-core.sh       # api-keys mode: no proxy build, no npm
if [[ "$SKIP_VAULT_SEED" == "1" ]]; then
    advance_state 3               # brain came from git, already seeded
else
    run_stage 30-vault-seed.sh
fi
run_stage 40-agents-wire.sh
run_stage 50-smoke-test.sh
# 60 (delivery) + 70 (autostart) are laptop stages: delivery is gateway
# config on servers, and stage 70 renders USER-scope units — the SYSTEM
# units below replace it. Advance state so 80's guard passes.
advance_state 7
run_stage 80-lab-seed.sh

# ------------------------------------------------------------------
# 6b. Profile homes: dispatcher runs ONLY in the default (root) gateway
# ------------------------------------------------------------------
GATEWAY_INSTANCES=(default hephaestus clio)
[[ "$TALARIA_LOCAL" == "1" ]] && GATEWAY_INSTANCES+=(talaria)

for profile in "${GATEWAY_INSTANCES[@]}"; do
    [[ "$profile" == "default" ]] && continue   # default = root HERMES_HOME (drop-in below)
    sudo -u "$SQUAD_USER" mkdir -p "$SQUAD_HOME/profiles/$profile/logs"
    sudo -u "$SQUAD_USER" SQUAD_HOME="$SQUAD_HOME" PROFILE="$profile" python3 << 'PYEOF'
import os
import yaml

root_cfg = os.path.join(os.environ['SQUAD_HOME'], 'config.yaml')
profile_cfg = os.path.join(os.environ['SQUAD_HOME'], 'profiles',
                           os.environ['PROFILE'], 'config.yaml')

cfg = {}
path = profile_cfg if os.path.exists(profile_cfg) else root_cfg
if os.path.exists(path):
    with open(path) as f:
        cfg = yaml.safe_load(f) or {}

cfg.setdefault('kanban', {})['dispatch_in_gateway'] = False
with open(profile_cfg, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False, sort_keys=False)
print(f"dispatch_in_gateway=false -> {profile_cfg}")
PYEOF
done

# ------------------------------------------------------------------
# 6c. Vault workspace symlinks (parameterized re-creation — stage 40 only
#     wires them on its first run; a re-clone of the brain loses them)
# ------------------------------------------------------------------
relink_workspaces() {
    local vault="$1"
    local agents=(Hermes Hephaestus Clio)
    [[ "$TALARIA_LOCAL" == "1" ]] && agents+=(Talaria)

    for name in "${agents[@]}"; do
        local agent_dir="$vault/agents/$name"
        sudo -u "$SQUAD_USER" mkdir -p "$agent_dir"
        for brain_file in hot.md Memories.md Skills.md AGENT_ROSTER.md; do
            sudo -u "$SQUAD_USER" ln -sfn "../../brain/$brain_file" "$agent_dir/$brain_file"
        done
        case "$name" in
            Hermes)
                sudo -u "$SQUAD_USER" ln -sfn ../../projects "$agent_dir/projects"
                ;;
            Hephaestus|Clio)
                if [[ ! -L "$agent_dir/projects" ]]; then
                    sudo -u "$SQUAD_USER" mkdir -p "$agent_dir/projects"
                    sudo -u "$SQUAD_USER" ln -sfn ../../../projects/agent-distribution-lab \
                        "$agent_dir/projects/agent-distribution-lab"
                fi
                ;;
        esac
    done
    log "Vault workspace symlinks re-created under $vault/agents/"
}
relink_workspaces "$VAULT_PATH"

# ------------------------------------------------------------------
# 7. systemd SYSTEM units
# ------------------------------------------------------------------
install -m 644 "$CHECKOUT/deploy/systemd/squad-mind.target" \
    "$CHECKOUT/deploy/systemd/hermes-gateway@.service" \
    "$CHECKOUT/deploy/systemd/llm-proxy@.service" \
    "$CHECKOUT/deploy/systemd/vault-autocommit.service" \
    "$CHECKOUT/deploy/systemd/vault-autocommit.timer" \
    "$CHECKOUT/deploy/systemd/squad-backup.service" \
    "$CHECKOUT/deploy/systemd/squad-backup.timer" \
    "$CHECKOUT/deploy/systemd/audit-export.service" \
    "$CHECKOUT/deploy/systemd/audit-export.timer" \
    /etc/systemd/system/

# Instance `default` is the orchestrator: root HERMES_HOME (its config.yaml
# carries kanban.dispatch_in_gateway: true from the bootstrap overlay) and
# no --profile flag — mirrors the reference deployment's root gateway.
mkdir -p /etc/systemd/system/hermes-gateway@default.service.d
cat > /etc/systemd/system/hermes-gateway@default.service.d/10-root-profile.conf << EOF
[Service]
Environment=HERMES_HOME=$SQUAD_HOME
ExecStart=
ExecStart=$VENV/bin/python -m hermes_cli.main gateway run --replace
EOF

if [[ "$TALARIA_LOCAL" == "1" ]]; then
    mkdir -p /etc/systemd/system/squad-mind.target.d
    cat > /etc/systemd/system/squad-mind.target.d/10-talaria.conf << 'EOF'
[Unit]
Wants=hermes-gateway@talaria.service
EOF
fi

systemctl daemon-reload
systemctl enable squad-mind.target
for profile in "${GATEWAY_INSTANCES[@]}"; do
    systemctl enable "hermes-gateway@${profile}.service"
done
TIMERS=(vault-autocommit squad-backup audit-export)
for timer in "${TIMERS[@]}"; do
    systemctl enable "${timer}.timer"
done
log "Units installed and enabled (squad-mind.target + ${GATEWAY_INSTANCES[*]} + timers: ${TIMERS[*]})"

# ------------------------------------------------------------------
# 8. Next steps
# ------------------------------------------------------------------
cat << EOF

=== Squad-Mind server install complete ===

Layout : $SQUAD_ROOT/{brain,hermes,archive,secrets}, checkout at $CHECKOUT
Units  : squad-mind.target + hermes-gateway@{${GATEWAY_INSTANCES[*]// /,}} (enabled, NOT started)

Next steps:
  1. Fill $SECRETS_DIR/.env with API keys (template: deploy/env/server.env.example
     — Vertex AI recommended; CLI-subscription proxies are dev/laptop only).
  2. systemctl start squad-mind.target
  3. systemctl status 'hermes-gateway@*' — all gateways should be active.
$( [[ "$TALARIA_LOCAL" == "1" ]] && echo "  4. sudo -u $SQUAD_USER ollama pull \$(see models.lock.yaml agents.talaria.model)" )

EOF
