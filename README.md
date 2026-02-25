# openclaw-agent

Personal exploration of the OpenClaw autonomous AI agent framework, running in a hardened container sandbox.

## Quick Start

```bash
# 1. Create secrets (prompts for API keys)
bash scripts/setup-secrets.sh

# 2. Set a gateway token in config/config.yaml
#    python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 3. Build and run
docker compose build
docker compose up -d

# 4. Verify
docker exec openclaw-sandbox whoami   # should print "openclaw"
```

## Security

The container runs with a defense-in-depth posture: non-root user, read-only root filesystem, all capabilities dropped, resource limits (1G RAM, 1 CPU, 100 PIDs), and file-based secrets. See [docs/threat-model.md](docs/threat-model.md) for the full threat model and verification checklist.

## Project Layout

```
Dockerfile              # Multi-stage build, non-root user
compose.yaml            # Hardened compose spec
config/config.yaml      # OpenClaw config (allowlist mode, minimal commands)
config/SOUL.md          # Agent personality
scripts/setup-secrets.sh
secrets/                # API keys (gitignored, never committed)
workspace/              # Disposable agent workspace (gitignored)
docs/threat-model.md    # Threat model and security controls
```
