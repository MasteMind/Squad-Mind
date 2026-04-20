#!/usr/bin/env bash
# Stage 0: Prerequisites & Environment Check
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 0

info "=== Stage 0: Prerequisites & Environment Check ==="

# ------------------------------------------------------------------
# 1. Detect OS
# ------------------------------------------------------------------
detect_platform

# ------------------------------------------------------------------
# 2. Check internet
# ------------------------------------------------------------------
if ! curl -I -s --max-time 10 https://github.com | head -1 | grep -q "200"; then
    die "Internet check failed: cannot reach https://github.com"
fi
info "Internet connectivity: OK"

# ------------------------------------------------------------------
# 3. Check disk space
# ------------------------------------------------------------------
FREE_GB=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | tr -d 'G')
if [[ "$FREE_GB" -lt 1 ]]; then
    die "Insufficient disk space: ${FREE_GB}GB free, need at least 1GB"
fi
info "Disk space: ${FREE_GB}GB free → OK"

# ------------------------------------------------------------------
# 4. Probe sudo
# ------------------------------------------------------------------
if sudo -n true 2>/dev/null; then
    info "Sudo available: YES"
    echo "SUDO=true" >> "$STATE_FILE"
else
    warn "Sudo not available. Will use user-space fallbacks."
    echo "SUDO=false" >> "$STATE_FILE"
fi

# ------------------------------------------------------------------
# 5. Check for existing Hermes
# ------------------------------------------------------------------
if [[ -d "$HOME/.hermes" ]]; then
    warn "Existing Hermes runtime found at ~/.hermes"
    warn "The installer is idempotent, but review scripts/uninstall.sh if you want a clean slate."
fi

# ------------------------------------------------------------------
# 6. Required commands
# ------------------------------------------------------------------
for cmd in curl bash python3 git; do
    require_command "$cmd"
done
info "Required commands: OK"

# ------------------------------------------------------------------
# 7. Python deps (uv preferred, pip fallback)
# ------------------------------------------------------------------
if command -v uv &>/dev/null; then
    info "Package manager: uv"
    uv pip install pyyaml requests --quiet 2>/dev/null || warn "Could not install Python deps via uv"
elif command -v pip3 &>/dev/null; then
    info "Package manager: pip3"
    pip3 install --user pyyaml requests --quiet 2>/dev/null || warn "Could not install Python deps via pip3"
else
    warn "Neither uv nor pip3 found. Some scripts may fail."
fi

# ------------------------------------------------------------------
# 8. Initialize state
# ------------------------------------------------------------------
set_step 0

info "=== Stage 0 complete ==="
