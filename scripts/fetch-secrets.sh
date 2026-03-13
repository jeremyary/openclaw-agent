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

# Vault connection
VAULT_ADDR="${VAULT_ADDR:-https://10.0.0.43:8200}"
VAULT_CACERT="${VAULT_CACERT:-/share/home-share/config/vault/tls/ca-cert.pem}"

# AppRole credentials
APPROLE_CREDS="${APPROLE_CREDS:-/share/home-share/config/vault/approle/openclaw.env}"

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

# Fix ownership for rootless Podman -- container UID 1000 maps to host UID 100999
podman unshare chown -R 1000:1000 "$SECRETS_DIR"

echo "Secrets rendered to $SECRETS_DIR"
ls -la "$SECRETS_DIR"
