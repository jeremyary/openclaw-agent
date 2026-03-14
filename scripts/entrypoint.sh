#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Gateway entrypoint for OpenClaw.
# Validates Podman socket access before starting the gateway.
# Secrets are mounted as files at /secrets/ (rendered by Vault).

set -euo pipefail

# Validate Docker/Podman socket is accessible (required for sandbox mode)
DOCKER_SOCK="/var/run/docker.sock"
if [ -S "$DOCKER_SOCK" ]; then
    if docker info >/dev/null 2>&1; then
        echo "entrypoint: Podman socket OK"
    else
        echo "entrypoint: WARNING -- socket exists but docker info failed (check permissions)"
    fi
else
    echo "entrypoint: WARNING -- $DOCKER_SOCK not found (sandbox mode will not work)"
fi

# Render config with LAN IP substitution (source config is mounted read-only)
CONFIG_SRC="${OPENCLAW_CONFIG_PATH:-/config/openclaw.json}"
CONFIG_RENDERED="/home/node/.openclaw/openclaw.json"
sed "s/__LAN_IP__/${OPENCLAW_LAN_IP:-127.0.0.1}/g" "$CONFIG_SRC" > "$CONFIG_RENDERED"
export OPENCLAW_CONFIG_PATH="$CONFIG_RENDERED"
echo "entrypoint: Config rendered with LAN_IP=${OPENCLAW_LAN_IP:-127.0.0.1}"

exec "$@"
