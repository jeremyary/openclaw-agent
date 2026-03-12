# openclaw-agent

Personal exploration of the OpenClaw autonomous AI agent framework, running in a hardened container sandbox.

## Quick Start

```bash
make setup-secrets    # Create Podman secrets (API key + gateway token)
make build            # Build container image
make run              # Start the sandbox
make verify           # Run 10-point security checklist
make chat             # Open the TUI to talk to the agent
```

## Make Targets

| Target | Description |
|--------|-------------|
| `build` | Build the container image |
| `push` | Push image to quay.io |
| `run` | Start the container |
| `stop` | Stop and remove the container |
| `logs` | Tail container logs |
| `verify` | Run 10-point sandbox verification |
| `chat` | Open the OpenClaw TUI |
| `shell` | Interactive shell in the container |
| `give` | Copy files to workspace: `make give src=<file>` |
| `setup-secrets` | Create Podman secrets for API keys |
| `clean` | Remove container, volumes, and image |

## Security

The container runs with a defense-in-depth posture: non-root user, read-only root filesystem, all capabilities dropped, resource limits (1G RAM, 1 CPU, 100 PIDs), and Podman encrypted secrets. See [docs/threat-model.md](docs/threat-model.md) for the full threat model and verification checklist.

## Project Layout

```
Dockerfile                # Multi-stage build, pinned OpenClaw 2026.3.11
compose.yaml              # Hardened Podman Compose spec
config/openclaw.json      # OpenClaw config (hardened, minimal tools)
config/SOUL.md            # Agent personality (read-only mount)
scripts/entrypoint.sh     # Secret injection into container env
scripts/setup-secrets.sh  # Podman encrypted secret creation
scripts/verify-sandbox.sh # 10-point security verification
docs/threat-model.md      # Threat model and security controls
Makefile                  # Convenience targets
workspace/                # Disposable agent workspace (gitignored)
openclaw-state/           # OpenClaw runtime state (gitignored)
```
