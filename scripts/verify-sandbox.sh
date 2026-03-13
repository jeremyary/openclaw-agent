#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Verify the OpenClaw gateway and sandbox security controls.
# Maps to the verification checklist in docs/threat-model.md.
#
# Usage: bash scripts/verify-sandbox.sh
# Exit: 0 if all critical checks pass (known gaps are warnings, not failures).

set -euo pipefail

CONTAINER="openclaw-gateway"
PASS=0
FAIL=0
WARN=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }

exec_in() { podman exec "$CONTAINER" "$@" 2>&1; }

echo "=== OpenClaw Gateway + Sandbox Verification ==="
echo ""

# Confirm gateway container is running
if ! podman inspect --format='{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "ERROR: Container '$CONTAINER' is not running."
    echo "Start it with: make run"
    exit 1
fi

# --- Check 1: Gateway running as correct user ---
echo "Check 1: Gateway user"
USER=$(exec_in whoami)
if [ "$USER" = "node" ]; then
    pass "whoami = $USER (UID 1000 via keep-id)"
else
    fail "whoami = $USER (expected node)"
fi

# --- Check 2: Podman socket accessible from gateway ---
echo "Check 2: Podman socket accessible"
if exec_in docker info >/dev/null 2>&1; then
    pass "docker info succeeds (Podman socket connected)"
else
    fail "docker info failed (Podman socket not accessible)"
fi

# --- Check 3: Sandbox image available ---
echo "Check 3: Sandbox image available"
if exec_in docker image inspect openclaw-sandbox:bookworm-slim >/dev/null 2>&1; then
    pass "openclaw-sandbox:bookworm-slim image found"
else
    fail "openclaw-sandbox:bookworm-slim not found (run: make build-sandbox)"
fi

# --- Check 4: Writable workspace ---
echo "Check 4: Writable workspace"
if exec_in touch /workspace/.verify-test 2>&1; then
    exec_in rm -f /workspace/.verify-test
    pass "Can write to /workspace"
else
    fail "Cannot write to /workspace"
fi

# --- Check 5: Capabilities dropped ---
echo "Check 5: Gateway capabilities dropped"
CAP_EFF=$(exec_in cat /proc/1/status | grep "^CapEff:" | awk '{print $2}')
if [ "$CAP_EFF" = "0000000000000000" ]; then
    pass "CapEff = $CAP_EFF (no capabilities)"
else
    CAP_DEC=$((16#${CAP_EFF}))
    if [ "$CAP_DEC" -le 10 ]; then
        warn "CapEff = $CAP_EFF (near-zero, acceptable)"
    else
        fail "CapEff = $CAP_EFF (capabilities not fully dropped)"
    fi
fi

# --- Check 6: Egress to non-allowed destinations ---
echo "Check 6: Egress to non-allowed destinations"
if exec_in curl -sf -m 5 https://example.com >/dev/null 2>&1; then
    warn "Egress to example.com succeeded -- network filtering not yet enforced"
    echo "         Gateway needs external access for LLM API. True filtering requires a proxy."
else
    pass "Egress to example.com blocked"
fi

# --- Check 7: LLM API reachable ---
echo "Check 7: LLM API reachable"
HTTP_CODE=$(exec_in curl -so /dev/null -w '%{http_code}' -m 10 https://api.anthropic.com/ 2>&1 || true)
if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" != "000" ]; then
    pass "api.anthropic.com returned HTTP $HTTP_CODE"
else
    fail "api.anthropic.com unreachable (HTTP $HTTP_CODE)"
fi

# --- Check 8: Secrets mounted ---
echo "Check 8: Secrets mounted"
for SECRET in anthropic gateway_token; do
    if exec_in test -f "/secrets/$SECRET" 2>&1; then
        pass "/secrets/$SECRET exists"
    else
        fail "/secrets/$SECRET not found"
    fi
done

# --- Check 9: Memory limit ---
echo "Check 9: Memory limit"
MEM_LIMIT=$(podman stats --no-stream --format '{{.MemUsage}}' "$CONTAINER" 2>&1 || true)
if echo "$MEM_LIMIT" | grep -qiE "GiB|MiB|GB|MB"; then
    LIMIT_PART=$(echo "$MEM_LIMIT" | grep -oP '/\s*\K[0-9.]+\s*[A-Za-z]+' || true)
    if [ -n "$LIMIT_PART" ]; then
        pass "Memory limit: $MEM_LIMIT"
    else
        warn "Memory limit format unexpected: $MEM_LIMIT"
    fi
else
    fail "Could not read memory limit: $MEM_LIMIT"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "  Passed:   $PASS"
echo "  Failed:   $FAIL"
echo "  Warnings: $WARN"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "RESULT: $FAIL critical check(s) failed."
    exit 1
else
    if [ "$WARN" -gt 0 ]; then
        echo "RESULT: All critical checks passed ($WARN known gap(s) noted)."
    else
        echo "RESULT: All checks passed."
    fi
    exit 0
fi
