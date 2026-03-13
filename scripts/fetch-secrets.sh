#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Fetch OpenClaw secrets from Vault and render to /tmp/openclaw-secrets/.
# Wraps the nas-vault fetch script with OpenClaw-specific AppRole credentials.
#
# Prerequisites:
#   - Vault running at VAULT_ADDR
#   - AppRole credentials accessible
#   - CA cert for TLS verification
#
# Usage: bash scripts/fetch-secrets.sh

set -euo pipefail

# Load .env if present (provides VAULT_ADDR, VAULT_CACERT, APPROLE_CREDS)
ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    set -a; source "$ENV_FILE"; set +a
fi

# Vault connection
VAULT_ADDR="${VAULT_ADDR:?Set VAULT_ADDR to your Vault server URL}"
VAULT_CACERT="${VAULT_CACERT:?Set VAULT_CACERT to your Vault CA cert path}"

# AppRole credentials
APPROLE_CREDS="${APPROLE_CREDS:?Set APPROLE_CREDS to your AppRole credentials file}"

# Output directory
SECRETS_DIR="/tmp/openclaw-secrets"

# Source AppRole credentials
if [ ! -f "$APPROLE_CREDS" ]; then
    echo "Error: AppRole credentials not found at $APPROLE_CREDS"
    echo "Set APPROLE_CREDS to the correct path."
    exit 1
fi
# shellcheck source=/dev/null
source "$APPROLE_CREDS"

export VAULT_ADDR VAULT_CACERT VAULT_ROLE_ID VAULT_SECRET_ID

# Delegate to the nas-vault fetch script
FETCH_SCRIPT="${FETCH_SCRIPT:-$HOME/git/nas-vault/scripts/fetch-secrets.sh}"

if [ ! -f "$FETCH_SCRIPT" ]; then
    echo "Error: Vault fetch script not found at $FETCH_SCRIPT"
    echo "Set FETCH_SCRIPT to the correct path."
    exit 1
fi

bash "$FETCH_SCRIPT" "secret/data/openclaw/api-keys" "$SECRETS_DIR"

# Ensure secrets are readable by the container user (UID 1000 via keep-id)
chmod 644 "$SECRETS_DIR"/*

echo "Secrets rendered to $SECRETS_DIR"
ls -la "$SECRETS_DIR"
