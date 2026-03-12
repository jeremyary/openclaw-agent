#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Container entrypoint for OpenClaw sandbox.
# Reads Podman secrets from /run/secrets/ and exports them as environment
# variables so OpenClaw can consume them via ${VAR} substitution in config.
# This keeps secrets out of config files, compose env sections, and CLI args.

set -euo pipefail

# Read secrets from mounted files into env vars
if [ -f /run/secrets/anthropic_api_key ]; then
    export ANTHROPIC_API_KEY
    ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
fi

if [ -f /run/secrets/gateway_token ]; then
    export OPENCLAW_GATEWAY_TOKEN
    OPENCLAW_GATEWAY_TOKEN=$(cat /run/secrets/gateway_token)
fi

# Hand off to tini + openclaw
exec "$@"
