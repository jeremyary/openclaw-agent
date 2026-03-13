# openclaw-agent

Personal exploration of the OpenClaw autonomous AI agent framework, running with built-in sandbox isolation.

## Quick Start

```bash
cp .env.example .env      # Fill in Vault and LAN IP values
make fetch-secrets        # Fetch secrets from Vault
make build build-sandbox  # Build gateway + sandbox images
make run                  # Start gateway and TLS proxy
make verify               # Run security verification checklist
make chat                 # Open the TUI to talk to the agent
```

## Make Targets

| Target | Description |
|--------|-------------|
| `build` | Build the gateway image |
| `build-sandbox` | Build the sandbox image |
| `run` | Start gateway and proxy |
| `stop` | Stop and remove containers |
| `logs` | Tail gateway logs |
| `verify` | Run sandbox verification checklist |
| `chat` | Open the OpenClaw TUI |
| `shell` | Interactive shell in the gateway |
| `give` | Copy files to workspace: `make give src=<file>` |
| `fetch-secrets` | Fetch secrets from Vault |
| `sandbox-list` | List active sandbox containers |
| `sandbox-explain` | Show sandbox configuration |
| `clean` | Remove containers, volumes, and images |

## Security

Gateway + sandbox architecture: the gateway spawns ephemeral, network-isolated sandbox containers per tool execution via the host Podman socket. Sandbox containers run with `network:none`, `capDrop:ALL`, and are destroyed after use. See [docs/threat-model.md](docs/threat-model.md) for the full threat model.

## Project Layout

```
Dockerfile                # Gateway image (official OpenClaw + Docker CLI)
Dockerfile.sandbox        # Sandbox image (Debian slim + dev tools)
compose.yaml              # Podman Compose (gateway + Caddy proxy)
config/openclaw.json      # OpenClaw config (sandbox mode, hardened tools)
config/SOUL.md            # Agent personality (read-only mount)
config/Caddyfile          # TLS reverse proxy for Control UI
scripts/entrypoint.sh     # Gateway entrypoint (socket validation)
scripts/fetch-secrets.sh  # Vault secret fetcher
scripts/gen-tls-cert.sh   # Self-signed TLS cert generator
scripts/verify-sandbox.sh # Security verification checklist
docs/threat-model.md      # Threat model and security controls
.env.example              # Environment template (copy to .env)
Makefile                  # Convenience targets
workspace/                # Disposable agent workspace (gitignored)
openclaw-state/           # OpenClaw runtime state (gitignored)
```
