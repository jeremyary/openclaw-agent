# OpenClaw Threat Model

> This project was developed with assistance from AI tools.

This document captures the threat model for running OpenClaw in a sandboxed container.
It is the reference for understanding why each security control exists.

---

## 1. OpenClaw Architecture Summary

OpenClaw is a TypeScript/Node.js 22+ autonomous AI agent framework with a hub-and-spoke
architecture:

| Component | Port | Purpose |
|-----------|------|---------|
| **Gateway** | 18789 | WebSocket control plane -- session management, tool execution, message routing |
| **Control Service** | 18791 | HTTP API for UI/control |
| **CDP Relay** | 18792 | Chrome DevTools Protocol for browser automation |

**Agent loop (ReAct pattern):** Receive message -> load context (SOUL.md, MEMORY.md, history) ->
call LLM with tools -> execute tool (shell, file I/O, browser, etc.) -> feed result back -> repeat
until final reply.

**Key capabilities that create risk:**
- `shell.exec` -- arbitrary shell commands with process-owner permissions
- `file.read/write/delete` -- unrestricted filesystem access
- `browser.*` -- full browser automation via CDP, including authenticated sessions
- Network access -- arbitrary HTTP/S requests from within the agent loop
- Memory persistence -- SOUL.md, MEMORY.md, daily logs, JSONL transcripts (poisonable)
- Multi-channel messaging -- WhatsApp, Telegram, Slack, Discord, etc.

---

## 2. Risk Registry

| # | Threat | Severity | Vector | Example |
|---|--------|----------|--------|---------|
| T1 | **Unrestricted shell execution** | Critical | Agent runs commands with host-user privileges | Agent deletes files, installs packages, modifies system config |
| T2 | **Filesystem exfiltration/destruction** | Critical | file.read/write/delete tools | Agent reads ~/.ssh/*, ~/.gnupg/*, deletes home directory |
| T3 | **Network egress / data exfiltration** | High | Arbitrary HTTP requests from agent | Agent sends API keys, file contents to attacker-controlled endpoint |
| T4 | **Prompt injection via tool output** | High | Malicious content in web pages, files, API responses | Injected instructions in a fetched web page redirect agent behavior |
| T5 | **Memory poisoning** | High | Indirect injection persists to MEMORY.md | Poisoned memory alters agent behavior in future sessions |
| T6 | **API key exposure** | High | Keys in env vars, podman inspect, container logs | Leaked API keys used for unauthorized access |
| T7 | **Supply chain: malicious ClawHub skills** | High | 824+ confirmed malicious skills on ClawHub | AMOS infostealer delivered via trojanized skills |
| T8 | **Browser session hijacking** | Medium | Extension relay accesses authenticated Chrome sessions | Agent accesses email, banking, cloud consoles via live cookies |
| T9 | **Gateway token theft (CVE-2026-25253)** | Critical | Control UI trusts gatewayUrl from query string | 1-click RCE via crafted link -- fixed in v2026.1.29 |
| T10 | **Runaway agent actions** | Medium | No human-in-the-loop for destructive ops | Email deletion incident -- agent misinterprets "suggest" as "execute" |
| T11 | **Resource exhaustion** | Low | Fork bomb, memory bomb, CPU spin | Agent-spawned process consumes all host resources |
| T12 | **Privilege escalation** | Medium | setuid binaries, sudo, capability abuse | Container escape via unpatched kernel or misconfigured caps |

---

## 3. Security Controls

### 3.1 Container Hardening

| Control | Setting | Mitigates |
|---------|---------|-----------|
| Non-root user | `user: "1000:1000"` | T12 |
| Drop all capabilities | `cap_drop: [ALL]` | T12 |
| No new privileges | `security_opt: [no-new-privileges:true]` | T12 |
| Seccomp profile | Default Podman seccomp | T12 |
| Read-only root FS | `read_only: true` | T2 |
| tmpfs for /tmp | `size=100m,noexec,nosuid,nodev` | T2, T12 |
| Memory limit | 1G | T11 |
| CPU limit | 1.0 | T11 |
| PID limit | 100 | T11 |

### 3.2 Network Controls

Only these destinations are permitted:

| Destination | Port | Purpose |
|-------------|------|---------|
| `api.anthropic.com` | 443 | Claude API |

Everything else should be blocked. Implementation options (in order of preference):
1. Podman network policies (if supported by the runtime)
2. Squid/tinyproxy forward proxy sidecar with domain allowlist
3. iptables rules on the Podman bridge network

### 3.3 Secrets Management

Secrets are managed by HashiCorp Vault (self-hosted on NAS) and rendered as files
into the container. No environment variables, no Podman secrets, no plain-text
files on disk.

**Architecture:**

1. Vault stores secrets encrypted at rest (Raft storage, auto-unseal)
2. `scripts/fetch-secrets.sh` authenticates via AppRole, renders one file per key to `/tmp/openclaw-secrets/`
3. Compose bind-mounts `/tmp/openclaw-secrets:/secrets:ro` into the container
4. OpenClaw reads secrets directly via `secrets.providers` file source (SecretRef)

**Why Vault + file mount over alternatives:**

| Concern | Env Vars | Podman Secrets | Vault + File Mount |
|---------|----------|----------------|--------------------|
| `podman inspect` | Visible | Not visible | Not visible |
| `/proc/*/environ` | Readable | Not present | Not present |
| Child process inheritance | Automatic | Not inherited | Not inherited |
| Plaintext on host disk | Via `.env` files | Encrypted store | tmpfs only |
| Centralized management | No | No | Yes (multi-service) |
| Rotation without restart | No | No | Re-run fetch script |
| Audit logging | No | No | Yes (Vault audit) |

**Access controls:**
- AppRole auth with scoped `openclaw` policy (read-only to `secret/data/openclaw/*`)
- Rendered files owned by container UID (rootless Podman mapping)
- Container mounts `/secrets` read-only
- OpenClaw reads files directly -- no env var conversion

Setup: `make fetch-secrets` (requires Vault access and AppRole credentials).

### 3.4 Workspace Isolation

The agent has a single writable directory: `/workspace` (bind-mounted from `./workspace/`).

- Disposable -- treat all contents as untrusted
- Host home directory, SSH keys, GPG keys are never mounted
- OpenClaw config is mounted read-only from `./config/`

### 3.5 OpenClaw Configuration Hardening

- `security: allowlist` -- default-deny for commands
- `ask: always` -- human approval before every tool execution
- Minimal tool profile with explicit deny list (see `config/openclaw.json`)
- No messaging channels
- No browser automation
- JSONL transcript logging for full audit trail

### 3.6 Disabled Features

| Feature | Status | Reason |
|---------|--------|--------|
| ClawHub skills | Not installed | T7 supply chain risk |
| Browser extension relay | Disabled | T8 session hijacking |
| Browser managed mode | Disabled | Reduced attack surface |
| Messaging channels | Disabled | Reduced attack surface |

---

## 4. Verification Checklist

Run these after deployment to confirm controls are active:

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | Non-root user | `podman exec openclaw-sandbox whoami` | `openclaw` |
| 2 | Read-only FS | `podman exec openclaw-sandbox touch /test` | Permission denied |
| 3 | Writable workspace | `podman exec openclaw-sandbox touch /workspace/test` | Success |
| 4 | tmpfs /tmp | `podman exec openclaw-sandbox mount \| grep /tmp` | `tmpfs` with `noexec` |
| 5 | No capabilities | `podman exec openclaw-sandbox cat /proc/1/status \| grep Cap` | Near-zero values |
| 6 | Egress blocked | `podman exec openclaw-sandbox curl https://example.com` | Connection refused/timeout |
| 7 | LLM API reachable | `podman exec openclaw-sandbox curl -I https://api.anthropic.com` | 200 or 401 |
| 8 | Secrets mounted | `podman exec openclaw-sandbox ls /secrets/` | Lists `anthropic`, `gateway_token` |
| 9 | PID limit | Fork bomb test (see below) | Fails after ~100 |
| 10 | Memory limit | `podman stats openclaw-sandbox --no-stream` | Limit shows 1G |

---

## 5. Tool Configuration Change Log

Track every change to the tool allow/deny lists in `config/openclaw.json` here:

| Date | Change | Reason | Risk Assessment |
|------|--------|--------|-----------------|
| (initial) | profile: minimal, deny: automation, runtime, browser, canvas, cron, gateway, sessions | Baseline locked-down config | Low -- minimal attack surface |
| (initial) | exec.security: deny, exec.ask: always, fs.workspaceOnly: true | Require approval for all exec, restrict FS to /workspace | Low -- defense in depth |
| 2026-03-13 | exec.security: deny -> allowlist, safeBins: [ls] | Enable directory listing for Phase 1 exploration; exec fully denied left no ls equivalent | Low -- ls is read-only, ask: always still enforced |

---

## 6. Future Work

- **gVisor/Firecracker:** Stronger isolation for untrusted code execution
- **Browser automation:** Managed-only Chromium in a separate container
- **Messaging channels:** CLI-only for now
- **Automated egress proxy:** Squid/tinyproxy sidecar with domain allowlist
- **Network policy enforcement:** Formalize iptables rules or use CNI plugins
