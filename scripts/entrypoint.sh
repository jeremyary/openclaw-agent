#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Container entrypoint for OpenClaw sandbox.
# Secrets are mounted as files at /secrets/ (rendered by Vault).
# OpenClaw reads them directly via secrets.providers file source.

set -euo pipefail

exec "$@"
