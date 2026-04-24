#!/usr/bin/env bash
# One-shot installer wrapper
# Usage: curl -sSL <url> | bash
# Or: ./scripts/install.sh

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/MasteMind/Squad-Mind.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/hermes-setup}"

echo "=== Hermes Setup Kit Installer ==="
echo ""

# Check prerequisites
for cmd in git curl bash python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Clone repo
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Directory $INSTALL_DIR already exists."
    if [[ -t 0 ]]; then
        read -p "Remove and re-clone? (yes/no): " confirm </dev/tty
    else
        echo "Directory exists. Use REPO_URL to override or remove it first."
        exit 1
    fi
    if [[ "$confirm" == "yes" ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo "Using existing directory."
    fi
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Install Python deps
if command -v uv &>/dev/null; then
    uv pip install pyyaml requests --quiet 2>/dev/null || true
elif command -v pip3 &>/dev/null; then
    pip3 install --user pyyaml requests --quiet 2>/dev/null || true
else
    echo "Warning: Neither uv nor pip3 found. Some scripts may fail."
fi

echo ""
echo "Repository ready at: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $INSTALL_DIR"
echo "  2. Run the interview: a capable CLI agent should read INTERVIEW.md"
echo "  3. Or run stages manually:"
echo "     ./bootstrap/00-prereqs.sh"
echo "     ./bootstrap/10-obsidian.sh"
echo "     ./bootstrap/20-hermes-core.sh"
echo "     ./bootstrap/30-vault-seed.sh"
echo "     ./bootstrap/40-agents-wire.sh"
echo "     ./bootstrap/50-smoke-test.sh"
echo ""
echo "For Docker fast-path: docker-compose -f docker-compose.bootstrap.yml up"
