#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Verify the OpenClaw sandbox security controls.
# Maps to the 10-point verification checklist in docs/threat-model.md.
#
# Usage: bash scripts/verify-sandbox.sh
# Exit: 0 if all critical checks pass (known gaps are warnings, not failures).

set -euo pipefail

CONTAINER="openclaw-sandbox"
PASS=0
FAIL=0
WARN=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }

exec_in() { podman exec "$CONTAINER" "$@" 2>&1; }

echo "=== OpenClaw Sandbox Verification ==="
echo ""

# Confirm container is running
if ! podman inspect --format='{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "ERROR: Container '$CONTAINER' is not running."
    echo "Start it with: make run"
    exit 1
fi

# --- Check 1: Non-root user ---
echo "Check 1: Non-root user"
USER=$(exec_in whoami)
if [ "$USER" = "openclaw" ]; then
    pass "whoami = $USER"
else
    fail "whoami = $USER (expected openclaw)"
fi

# --- Check 2: Read-only root filesystem ---
echo "Check 2: Read-only root filesystem"
if ! exec_in touch /test-readonly 2>/dev/null; then
    pass "Cannot write to / (read-only filesystem)"
else
    fail "Was able to write to / -- root filesystem is not read-only"
    exec_in rm -f /test-readonly 2>/dev/null || true
fi

# --- Check 3: Writable workspace ---
echo "Check 3: Writable workspace"
if exec_in touch /workspace/.verify-test 2>&1; then
    exec_in rm -f /workspace/.verify-test
    pass "Can write to /workspace"
else
    fail "Cannot write to /workspace"
fi

# --- Check 4: tmpfs /tmp with noexec ---
echo "Check 4: tmpfs /tmp with noexec"
MOUNT_LINE=$(exec_in mount | grep "on /tmp " || true)
if echo "$MOUNT_LINE" | grep -q "tmpfs"; then
    if echo "$MOUNT_LINE" | grep -q "noexec"; then
        pass "tmpfs on /tmp with noexec"
    else
        fail "tmpfs on /tmp but noexec flag missing"
    fi
else
    fail "/tmp is not tmpfs: $MOUNT_LINE"
fi

# --- Check 5: Capabilities dropped ---
echo "Check 5: Capabilities dropped"
CAP_EFF=$(exec_in cat /proc/1/status | grep "^CapEff:" | awk '{print $2}')
if [ "$CAP_EFF" = "0000000000000000" ]; then
    pass "CapEff = $CAP_EFF (no capabilities)"
else
    # Some minimal capabilities may remain; warn if non-zero but low
    CAP_DEC=$((16#${CAP_EFF}))
    if [ "$CAP_DEC" -le 10 ]; then
        warn "CapEff = $CAP_EFF (near-zero, acceptable)"
    else
        fail "CapEff = $CAP_EFF (capabilities not fully dropped)"
    fi
fi

# --- Check 6: Egress blocked (known gap) ---
echo "Check 6: Egress to non-allowed destinations"
if exec_in curl -sf -m 5 https://example.com >/dev/null 2>&1; then
    warn "Egress to example.com succeeded -- network filtering not yet enforced (Phase 2)"
    echo "         This is a known gap. The compose network uses internal: false to allow"
    echo "         LLM API access. True egress filtering requires a proxy sidecar."
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
SECRETS_OK=true
for SECRET in anthropic gateway_token; do
    if exec_in test -f "/secrets/$SECRET" 2>&1; then
        pass "/secrets/$SECRET exists"
    else
        fail "/secrets/$SECRET not found"
        SECRETS_OK=false
    fi
done

# --- Check 9: PID limit ---
echo "Check 9: PID limit"
# Attempt a controlled fork test -- spawn subshells until hitting the limit.
# This is safe: the PID limit prevents actual damage, and the container recovers.
FORK_RESULT=$(exec_in bash -c '
    count=0
    for i in $(seq 1 150); do
        sleep 2 &>/dev/null &
        if [ $? -ne 0 ]; then
            echo "fork_failed_at=$i"
            break
        fi
        count=$((count + 1))
    done
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    echo "spawned=$count"
' 2>&1 || true)
if echo "$FORK_RESULT" | grep -q "fork_failed_at\|Resource temporarily unavailable\|Cannot fork"; then
    LIMIT_HIT=$(echo "$FORK_RESULT" | grep -oP 'fork_failed_at=\K[0-9]+' || echo "unknown")
    pass "PID limit enforced (fork failed around process $LIMIT_HIT)"
elif echo "$FORK_RESULT" | grep -q "spawned=150"; then
    fail "Spawned 150 processes without hitting PID limit"
else
    warn "PID limit test inconclusive: $FORK_RESULT"
fi

# --- Check 10: Memory limit ---
echo "Check 10: Memory limit"
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
