# This project was developed with assistance from AI tools.
#
# Gateway Containerfile for OpenClaw with built-in sandbox support.
# Uses the official OpenClaw image as base; adds Docker CLI so the gateway
# can spawn sandbox containers via the host Podman socket.

FROM ghcr.io/openclaw/openclaw:2026.3.12

USER root

# Install Docker CLI (used by OpenClaw to manage sandbox containers).
# Only the CLI is needed -- the daemon runs on the host via Podman socket.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        docker.io \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Patch ANTHROPIC_MODEL_ALIASES TDZ crash (openclaw#45170).
# Remove this block when upgrading to a version with the fix (v2026.3.13+).
COPY scripts/patch-anthropic-tdz.sh /tmp/patch-anthropic-tdz.sh
RUN bash /tmp/patch-anthropic-tdz.sh /app/dist && rm /tmp/patch-anthropic-tdz.sh

# Copy entrypoint script (validates socket before starting gateway)
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create directories the container needs at runtime
RUN mkdir -p /workspace /home/node/.openclaw \
    && chown -R node:node /workspace /home/node/.openclaw

USER node
WORKDIR /workspace

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
CMD ["openclaw", "gateway", "run", "--port", "18789", "--bind", "lan"]
