#!/usr/bin/env bash
# Stage 2: Install Hermes Agent Runtime (~/.hermes)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 2

info "=== Stage 2: Hermes Runtime Setup ==="

require_file "setup_answers.yaml"

HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

info "Hermes home: $HERMES_HOME"

# ------------------------------------------------------------------
# Create runtime skeleton
# ------------------------------------------------------------------
mkdir -p "$HERMES_HOME"/{bots,profiles,bin,scripts}
chmod 700 "$HERMES_HOME"

# Copy templates if they exist
if [[ -d "templates/runtime/hermes" ]]; then
    cp -r templates/runtime/hermes/* "$HERMES_HOME/" 2>/dev/null || true
fi

info "Runtime permissions: $(ls -ld "$HERMES_HOME" | awk '{print $1}')"

set_step 2
info "=== Stage 2 complete ==="
