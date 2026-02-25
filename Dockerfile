# This project was developed with assistance from AI tools.
#
# Multi-stage build for OpenClaw sandbox container.
# Security controls: non-root user, minimal packages, no dev dependencies in final image.

# ---------------------------------------------------------------------------
# Stage 1 — build / install dependencies
# ---------------------------------------------------------------------------
FROM node:22-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install OpenClaw globally so we can copy the result into the runtime stage.
# Pin to a version >= 2026.2.15 (patches CVE-2026-25253).
# Check https://github.com/openclaw/openclaw/releases for the latest stable tag
# and replace the version below before building.
ARG OPENCLAW_VERSION=latest
RUN npm install -g "openclaw@${OPENCLAW_VERSION}" --ignore-scripts

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM node:22-slim AS runtime

# Minimal runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user (UID/GID 1000)
RUN groupadd --gid 1000 openclaw \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash openclaw

# Copy the globally-installed OpenClaw from the builder stage
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin /usr/local/bin

# Create directories the container needs at runtime.
# /workspace is the only writable directory (bind-mounted from host).
# /config is read-only (bind-mounted from host).
RUN mkdir -p /workspace /config \
    && chown openclaw:openclaw /workspace

USER openclaw
WORKDIR /workspace

# Tini as PID 1 — reaps zombies and forwards signals correctly.
ENTRYPOINT ["tini", "--"]
CMD ["openclaw", "start", "--config", "/config/config.yaml"]
