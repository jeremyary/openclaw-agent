#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Create Podman secrets for OpenClaw API keys.
# Secrets are stored in Podman's encrypted secret store -- no plain-text files on disk.
#
# Usage: bash scripts/setup-secrets.sh

set -euo pipefail

echo "=== OpenClaw Secrets Setup (Podman) ==="
echo ""
echo "This script creates Podman secrets for API keys."
echo "Keys are stored in Podman's encrypted secret store (not plain-text files)."
echo ""

# --- Anthropic API key ---
if podman secret inspect anthropic_api_key &>/dev/null; then
    echo "[OK] anthropic_api_key already exists -- skipping."
    echo "     To replace: podman secret rm anthropic_api_key && re-run this script."
else
    echo "Enter your Anthropic API key (input is hidden):"
    read -rs ANTHROPIC_KEY
    if [ -z "$ANTHROPIC_KEY" ]; then
        echo "[SKIP] No key entered."
    else
        printf '%s' "$ANTHROPIC_KEY" | podman secret create anthropic_api_key -
        echo "[OK] anthropic_api_key created."
    fi
    unset ANTHROPIC_KEY
fi

# --- Gateway token ---
if podman secret inspect gateway_token &>/dev/null; then
    echo "[OK] gateway_token already exists -- skipping."
    echo "     To replace: podman secret rm gateway_token && re-run this script."
else
    echo ""
    TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    printf '%s' "$TOKEN" | podman secret create gateway_token -
    echo "[OK] gateway_token created (auto-generated)."
    unset TOKEN
fi

echo ""
echo "=== Done ==="
echo "Verify with: podman secret ls"
echo ""
echo "Next steps:"
echo "  1. Review config/openclaw.json"
echo "  2. make build"
echo "  3. make run"
