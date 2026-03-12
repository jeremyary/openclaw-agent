# This project was developed with assistance from AI tools.
#
# Multi-stage Containerfile for OpenClaw sandbox.
# Security controls: non-root user, minimal packages, no dev dependencies in final image.

# ---------------------------------------------------------------------------
# Stage 1 -- build / install dependencies
# ---------------------------------------------------------------------------
FROM node:22-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Pin OpenClaw version. Check https://github.com/openclaw/openclaw/releases
# before changing. Version 2026.3.11 is the current verified version.
ARG OPENCLAW_VERSION=2026.3.11
RUN npm install -g "openclaw@${OPENCLAW_VERSION}" --ignore-scripts

# ---------------------------------------------------------------------------
# Stage 2 -- runtime
# ---------------------------------------------------------------------------
FROM node:22-slim AS runtime

# Minimal runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Reuse the existing node user/group (UID/GID 1000), rename for clarity.
RUN groupmod --new-name openclaw node \
    && usermod --login openclaw --home /home/openclaw --move-home node

# Copy the globally-installed OpenClaw from the builder stage
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy entrypoint script (reads Podman secrets into env vars)
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create directories the container needs at runtime.
# /workspace is the only writable directory (bind-mounted from host).
RUN mkdir -p /workspace /home/openclaw/.openclaw \
    && chown -R openclaw:openclaw /workspace /home/openclaw/.openclaw

USER openclaw
WORKDIR /workspace

# Tini as PID 1 -- reaps zombies and forwards signals correctly.
# Entrypoint reads secrets and execs the CMD.
ENTRYPOINT ["tini", "--", "entrypoint.sh"]
CMD ["openclaw", "gateway", "run", "--port", "18789", "--bind", "lan"]
