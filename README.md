# openclaw-agent

Personal exploration of the OpenClaw autonomous AI agent framework, running in a hardened container sandbox.

## Quick Start

```bash
# 1. Create Podman secrets (API keys + auto-generated gateway token)
make setup-secrets

# 2. Build and run
make build
make run

# 3. Verify security controls
make verify
```

## Security

The container runs with a defense-in-depth posture: non-root user, read-only root filesystem, all capabilities dropped, resource limits (1G RAM, 1 CPU, 100 PIDs), and Podman encrypted secrets. See [docs/threat-model.md](docs/threat-model.md) for the full threat model and verification checklist.

## Project Layout

```
Dockerfile              # Multi-stage build, non-root user
compose.yaml            # Hardened compose spec
config/openclaw.json    # OpenClaw config (hardened, minimal tools)
config/SOUL.md          # Agent personality
scripts/setup-secrets.sh # Podman secret creation
scripts/verify-sandbox.sh # 10-point security verification
workspace/              # Disposable agent workspace (gitignored)
docs/threat-model.md    # Threat model and security controls
Makefile                # Convenience targets (build, run, verify, etc.)
```
