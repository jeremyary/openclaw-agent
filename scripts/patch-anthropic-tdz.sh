#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Patch for OpenClaw v2026.3.12 ANTHROPIC_MODEL_ALIASES TDZ crash.
# See: https://github.com/openclaw/openclaw/issues/45170
#
# The bundler places a const declaration after the function that references it,
# causing a ReferenceError on any config load. This script inlines the alias
# map to remove the TDZ dependency. Must patch ALL affected bundles -- patching
# only one causes silent message drops (see issue comment by doldrums2025).
#
# This patch is temporary and should be removed when upgrading to a version
# that fixes the bug (v2026.3.13+).

set -euo pipefail

DIST_DIR="${1:-/app/dist}"
OLD='return ANTHROPIC_MODEL_ALIASES[trimmed.toLowerCase()] ?? trimmed;'
NEW='const aliases = {"opus-4.6":"claude-opus-4-6","opus-4.5":"claude-opus-4-5","sonnet-4.6":"claude-sonnet-4-6","sonnet-4.5":"claude-sonnet-4-5"};return aliases[trimmed.toLowerCase()] ?? trimmed;'

patched=0
for f in "$DIST_DIR"/*.js; do
    if grep -qF "$OLD" "$f"; then
        sed -i "s|$OLD|$NEW|" "$f"
        echo "Patched: $f"
        patched=$((patched + 1))
    fi
done

if [ "$patched" -eq 0 ]; then
    echo "ERROR: No files matched the TDZ pattern. The bundle may have changed." >&2
    exit 1
fi

echo "Patched $patched file(s)."
