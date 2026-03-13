# OpenClaw Threat Model

> This project was developed with assistance from AI tools.

This document captures the threat model for running OpenClaw with built-in sandbox mode.
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

**Deployment architecture:**

```
Host (rootless Podman)
  |
  +-- Gateway container (openclaw-gateway)
  |     Runs OpenClaw gateway process
  |     Mounts Podman socket to spawn sandbox containers
  |     Docker CLI installed for sandbox management
  |     userns_mode: keep-id (host UID 1000 = container UID 1000)
  |     cap_drop: ALL, no-new-privileges
  |
  +-- Sandbox containers (spawned by OpenClaw per tool execution)
  |     Image: openclaw-sandbox:bookworm-slim
  |     network:none, capDrop:ALL, readOnlyRoot, ephemeral
  |     Workspace mounted rw; no socket access
  |
  +-- Caddy container (TLS proxy for Control UI)
```

**Agent loop (ReAct pattern):** Receive message -> load context (SOUL.md, MEMORY.md, history) ->
call LLM with tools -> execute tool in sandbox -> feed result back -> repeat until final reply.

**Key capabilities that create risk:**
- `shell.exec` -- arbitrary shell commands (now isolated in sandbox containers)
- `file.read/write/delete` -- filesystem access (sandbox has workspace only)
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
| T13 | **Podman socket exposure to gateway** | Medium | Gateway container has Podman socket access | Compromised gateway could spawn privileged containers or access host resources |

---

## 3. Security Controls

### 3.1 Container Hardening

**Gateway container:**

| Control | Setting | Mitigates |
|---------|---------|-----------|
| Non-root user | `userns_mode: keep-id` (UID 1000) | T12 |
| Drop all capabilities | `cap_drop: [ALL]` | T12 |
| No new privileges | `security_opt: [no-new-privileges:true]` | T12 |
| Seccomp profile | Default Podman seccomp | T12 |
| Memory limit | 512M | T11 |
| CPU limit | 0.5 | T11 |

**Sandbox containers (spawned per tool execution):**

| Control | Setting | Mitigates |
|---------|---------|-----------|
| Network isolation | `network: none` | T3 |
| Drop all capabilities | `capDrop: [ALL]` | T12 |
| Ephemeral | Destroyed after use | T2, T5 |
| No socket access | Socket not mounted | T13 |
| Workspace only | `workspaceAccess: rw` | T2 |

### 3.2 Network Controls

**Gateway** needs external access for the LLM API. Only these destinations are intended:

| Destination | Port | Purpose |
|-------------|------|---------|
| `api.anthropic.com` | 443 | Claude API |

**Sandbox containers** have `network: none` -- completely isolated from the network.
This is the primary defense against T3 (data exfiltration from tool execution).

Gateway egress filtering (blocking non-API traffic) remains a future improvement:
1. Podman network policies (if supported by the runtime)
2. Squid/tinyproxy forward proxy sidecar with domain allowlist
3. iptables rules on the Podman bridge network

### 3.3 Secrets Management

Secrets are managed by HashiCorp Vault (self-hosted on NAS) and rendered as files
into the gateway container. No environment variables, no Podman secrets, no plain-text
files on disk.

**Architecture:**

1. Vault stores secrets encrypted at rest (Raft storage, auto-unseal)
2. `scripts/fetch-secrets.sh` authenticates via AppRole, renders one file per key to `/tmp/openclaw-secrets/`
3. Compose bind-mounts `/tmp/openclaw-secrets:/secrets:ro` into the gateway container
4. OpenClaw reads secrets directly via `secrets.providers` file source (SecretRef)

**Secrets are only in the gateway container -- sandbox containers never have access.**

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

The agent workspace (`/workspace`) is bind-mounted from `./workspace/`.

- Gateway has read-write access
- Sandbox containers have read-write access (via `workspaceAccess: rw`)
- Disposable -- treat all contents as untrusted
- Host home directory, SSH keys, GPG keys are never mounted
- OpenClaw config is mounted read-only from `./config/`

### 3.5 OpenClaw Configuration Hardening

- `sandbox.mode: all` -- all tool execution runs in isolated containers
- `exec.security: allowlist` -- default-deny for commands
- `exec.ask: always` -- human approval before every tool execution (fires at sandbox boundary)
- Minimal tool profile with explicit deny list (see `config/openclaw.json`)
- No messaging channels
- No browser automation
- JSONL transcript logging for full audit trail

### 3.6 Podman Socket Security (T13)

The gateway container mounts the host Podman socket to manage sandbox containers.
This is a deliberate trade-off: sandbox isolation requires socket access.

**Mitigations:**
- Rootless Podman -- socket has no host root access
- Gateway runs as non-root (UID 1000 via keep-id)
- `cap_drop: ALL` + `no-new-privileges` on gateway
- Sandbox containers cannot access the socket
- Default Podman seccomp profile restricts syscalls

**Residual risk:** A compromised gateway process could use the socket to spawn
containers with host mounts. This is bounded by rootless Podman's restrictions
(no --privileged, no host PID/network namespace by default).

### 3.7 Disabled Features

| Feature | Status | Reason |
|---------|--------|--------|
| ClawHub skills | Not installed | T7 supply chain risk |
| Browser extension relay | Disabled | T8 session hijacking |
| Browser managed mode | Disabled | Reduced attack surface |
| Messaging channels | Disabled | Reduced attack surface |

---

## 4. Verification Checklist

Run `make verify` after deployment to confirm controls are active:

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | Gateway user | `podman exec openclaw-gateway whoami` | `node` (UID 1000) |
| 2 | Podman socket | `podman exec openclaw-gateway docker info` | Success |
| 3 | Sandbox image | `podman exec openclaw-gateway docker image inspect openclaw-sandbox:bookworm-slim` | Found |
| 4 | Writable workspace | `podman exec openclaw-gateway touch /workspace/test` | Success |
| 5 | No capabilities | `podman exec openclaw-gateway cat /proc/1/status \| grep Cap` | Near-zero values |
| 6 | Egress to non-API | `podman exec openclaw-gateway curl https://example.com` | Warn (filtering not yet enforced) |
| 7 | LLM API reachable | `podman exec openclaw-gateway curl -I https://api.anthropic.com` | 200 or 401 |
| 8 | Secrets mounted | `podman exec openclaw-gateway ls /secrets/` | Lists `anthropic`, `gateway_token` |
| 9 | Memory limit | `podman stats openclaw-gateway --no-stream` | Limit shows 512M |

---

## 5. Tool Configuration Change Log

Track every change to the tool allow/deny lists in `config/openclaw.json` here:

| Date | Change | Reason | Risk Assessment |
|------|--------|--------|-----------------|
| (initial) | profile: minimal, deny: automation, runtime, browser, canvas, cron, gateway, sessions | Baseline locked-down config | Low -- minimal attack surface |
| (initial) | exec.security: deny, exec.ask: always, fs.workspaceOnly: true | Require approval for all exec, restrict FS to /workspace | Low -- defense in depth |
| 2026-03-13 | exec.security: deny -> allowlist, safeBins: [ls] | Enable directory listing for Phase 1 exploration; exec fully denied left no ls equivalent | Low -- ls is read-only, ask: always still enforced |
| 2026-03-13 | sandbox.mode: off -> all | Enable built-in sandbox mode; tool execution in isolated containers | Medium -- adds Podman socket exposure to gateway, but sandbox containers are network:none with capDrop:ALL |

---

## 6. Security Trade-offs: External Hardening vs Built-in Sandbox

| Aspect | Before (external hardening) | After (built-in sandbox) |
|--------|---------------------------|--------------------------|
| Tool isolation | Same container as gateway | Separate containers, network:none |
| exec approvals | Inert (no sandbox boundary) | Functional (sandbox-to-host boundary) |
| Attack surface | Minimal (1 container) | +Podman socket to gateway |
| Tool network access | Shared with gateway | Completely isolated |
| Complexity | 1 container | Gateway + sandbox + socket |
| Filesystem isolation | read_only on gateway | readOnlyRoot per sandbox |

---

## 7. Future Work

- **gVisor/Firecracker:** Stronger isolation for untrusted code execution
- **Browser automation:** Managed-only Chromium in a separate container
- **Messaging channels:** CLI-only for now
- **Automated egress proxy:** Squid/tinyproxy sidecar with domain allowlist
- **Network policy enforcement:** Formalize iptables rules or use CNI plugins
