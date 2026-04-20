#!/usr/bin/env bash
# Common helpers for Hermes bootstrap stages
# Source this from every stage script: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# ------------------------------------------------------------------
# Config
# ------------------------------------------------------------------
STATE_FILE="${STATE_FILE:-hermes-setup.state}"
LOG_DIR="${LOG_DIR:-bootstrap/log}"
mkdir -p "$LOG_DIR"

# ------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------
log() {
    local level="$1"
    shift
    local msg="[$(date -Iseconds)] [$level] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_DIR/bootstrap.log"
}

info()  { log "INFO" "$@"; }
warn()  { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }

die() {
    error "$@"
    exit 1
}

# ------------------------------------------------------------------
# State Management
# ------------------------------------------------------------------
get_step() {
    if [[ -f "$STATE_FILE" ]]; then
        grep "^STEP=" "$STATE_FILE" | cut -d= -f2 || echo "0"
    else
        echo "0"
    fi
}

set_step() {
    local step="$1"
    local tmpfile="${STATE_FILE}.tmp"
    {
        echo "STEP=${step}"
        echo "LAST_RUN=$(date -Iseconds)"
        echo "PLATFORM=${PLATFORM:-unknown}"
    } > "$tmpfile"
    mv "$tmpfile" "$STATE_FILE"
    info "State advanced to STEP=${step}"
}

# ------------------------------------------------------------------
# OS Detection
# ------------------------------------------------------------------
detect_platform() {
    case "$(uname -s)" in
        Darwin*)  PLATFORM="macOS" ;;
        Linux*)
            if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
                PLATFORM="WSL"
            else
                PLATFORM="Linux"
            fi
            ;;
        *)        PLATFORM="unknown" ;;
    esac
    export PLATFORM
    info "Detected platform: $PLATFORM"
}

# ------------------------------------------------------------------
# Package Installation
# ------------------------------------------------------------------
install_package() {
    local pkg="$1"
    info "Installing package: $pkg"

    if command -v apt-get &>/dev/null; then
        if sudo -n true 2>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$pkg"
        else
            warn "No sudo available. Cannot install $pkg via apt."
            return 1
        fi
    elif command -v dnf &>/dev/null; then
        if sudo -n true 2>/dev/null; then
            sudo dnf install -y "$pkg"
        else
            warn "No sudo available. Cannot install $pkg via dnf."
            return 1
        fi
    elif command -v pacman &>/dev/null; then
        if sudo -n true 2>/dev/null; then
            sudo pacman -S --noconfirm "$pkg"
        else
            warn "No sudo available. Cannot install $pkg via pacman."
            return 1
        fi
    elif command -v brew &>/dev/null; then
        brew install "$pkg"
    else
        die "No supported package manager found (apt, dnf, pacman, brew)"
    fi
}

# ------------------------------------------------------------------
# Backup
# ------------------------------------------------------------------
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        info "Backed up $file to $backup"
    fi
}

# ------------------------------------------------------------------
# Validation Helpers
# ------------------------------------------------------------------
require_command() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null || die "Required command not found: $cmd"
}

require_file() {
    local file="$1"
    [[ -f "$file" ]] || die "Required file not found: $file"
}

# ------------------------------------------------------------------
# YAML Reading (minimal, no external deps)
# ------------------------------------------------------------------
read_yaml_key() {
    local file="$1"
    local key="$2"
    python3 -c "
import yaml, sys
try:
    data = yaml.safe_load(open('$file'))
    keys = '$key'.split('.')
    for k in keys:
        data = data[k]
    print(data)
except Exception as e:
    sys.exit(1)
" 2>/dev/null
}

# ------------------------------------------------------------------
# Entry Guard
# ------------------------------------------------------------------
# Each stage script should call this at the top
guard_step() {
    local expected="$1"
    local current
    current=$(get_step)
    if [[ "$current" -lt "$((expected - 1))" ]]; then
        die "Step $expected requires step $((expected - 1)) to be complete first. Current step: $current"
    fi
    if [[ "$current" -ge "$expected" ]]; then
        info "Step $expected already complete. Skipping."
        exit 0
    fi
}
