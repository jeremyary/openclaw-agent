#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Create the secrets directory and prompt for API keys.
# Usage: bash scripts/setup-secrets.sh

set -euo pipefail

SECRETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/secrets"

echo "=== OpenClaw Secrets Setup ==="
echo ""
echo "This script creates the secrets directory and API key files."
echo "Keys are stored as plain text files (the weakest link — see docs/threat-model.md)."
echo ""

# Create secrets directory with owner-only permissions
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# --- Anthropic API key ---
if [ -f "$SECRETS_DIR/anthropic_api_key.txt" ]; then
    echo "[OK] anthropic_api_key.txt already exists — skipping."
else
    echo "Enter your Anthropic API key (input is hidden):"
    read -rs ANTHROPIC_KEY
    if [ -z "$ANTHROPIC_KEY" ]; then
        echo "[SKIP] No key entered — creating empty placeholder."
        touch "$SECRETS_DIR/anthropic_api_key.txt"
    else
        printf '%s' "$ANTHROPIC_KEY" > "$SECRETS_DIR/anthropic_api_key.txt"
        echo "[OK] anthropic_api_key.txt written."
    fi
    chmod 600 "$SECRETS_DIR/anthropic_api_key.txt"
fi

# --- OpenAI API key (optional) ---
if [ -f "$SECRETS_DIR/openai_api_key.txt" ]; then
    echo "[OK] openai_api_key.txt already exists — skipping."
else
    echo ""
    echo "Enter your OpenAI API key (optional — press Enter to skip):"
    read -rs OPENAI_KEY
    if [ -z "$OPENAI_KEY" ]; then
        echo "[SKIP] No key entered — creating empty placeholder."
        touch "$SECRETS_DIR/openai_api_key.txt"
    else
        printf '%s' "$OPENAI_KEY" > "$SECRETS_DIR/openai_api_key.txt"
        echo "[OK] openai_api_key.txt written."
    fi
    chmod 600 "$SECRETS_DIR/openai_api_key.txt"
fi

echo ""
echo "=== Done ==="
echo "Secrets directory: $SECRETS_DIR"
echo "Permissions: $(stat -c '%a' "$SECRETS_DIR") (should be 700)"
echo ""
echo "Next steps:"
echo "  1. Review config/config.yaml and set a gateway token"
echo "  2. docker compose build"
echo "  3. docker compose up -d"
