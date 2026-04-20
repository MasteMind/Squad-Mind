#!/usr/bin/env bash
# Stage 1: Install Obsidian (or Skip)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 1

info "=== Stage 1: Obsidian Installation ==="

require_file "setup_answers.yaml"

INSTALL_MODE=$(read_yaml_key setup_answers.yaml "install.mode" || echo "gui")

if [[ "$INSTALL_MODE" == "headless" ]]; then
    info "Headless mode requested. Skipping Obsidian GUI installation."
    set_step 1
    exit 0
fi

# ------------------------------------------------------------------
# Download & Install
# ------------------------------------------------------------------
OBSIDIAN_VERSION="1.8.10"

if [[ "$PLATFORM" == "Linux" ]]; then
    DEB_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
    DEB_FILE="/tmp/obsidian_${OBSIDIAN_VERSION}_amd64.deb"

    info "Downloading Obsidian ${OBSIDIAN_VERSION} for Linux..."
    curl -L -o "$DEB_FILE" "$DEB_URL"

    if [[ -f "bootstrap/lib/checksums.txt" ]] && grep -q "obsidian_${OBSIDIAN_VERSION}_amd64.deb" bootstrap/lib/checksums.txt; then
        info "Verifying checksum..."
        sha256sum -c bootstrap/lib/checksums.txt | grep "$DEB_FILE" || die "Checksum mismatch"
    else
        warn "No checksum found in bootstrap/lib/checksums.txt. Proceeding without verification."
    fi

    info "Installing Obsidian .deb package..."
    if sudo -n true 2>/dev/null; then
        # Pre-answer debconf prompts
        echo "obsidian obsidian/license note" | sudo debconf-set-selections 2>/dev/null || true
        sudo dpkg -i "$DEB_FILE" || sudo apt-get install -f -y
    else
        warn "No sudo. Cannot install .deb system-wide."
        warn "Manual install: dpkg -i $DEB_FILE"
        die "Obsidian installation requires sudo on Linux. Run with --headless to skip."
    fi

    rm -f "$DEB_FILE"

elif [[ "$PLATFORM" == "macOS" ]]; then
    DMG_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.dmg"
    DMG_FILE="/tmp/Obsidian-${OBSIDIAN_VERSION}.dmg"

    info "Downloading Obsidian ${OBSIDIAN_VERSION} for macOS..."
    curl -L -o "$DMG_FILE" "$DMG_URL"

    info "Mounting DMG..."
    hdiutil attach "$DMG_FILE" -nobrowse -mountpoint /Volumes/Obsidian

    info "Copying Obsidian.app to /Applications..."
    cp -R "/Volumes/Obsidian/Obsidian.app" /Applications/

    info "Removing quarantine attribute..."
    xattr -rd com.apple.quarantine /Applications/Obsidian.app 2>/dev/null || true

    hdiutil detach /Volumes/Obsidian
    rm -f "$DMG_FILE"

else
    die "Unsupported platform for Obsidian install: $PLATFORM. Use --headless."
fi

set_step 1
info "=== Stage 1 complete ==="
