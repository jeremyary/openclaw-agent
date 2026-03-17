# This project was developed with assistance from AI tools.
#
# Gateway Containerfile for OpenClaw with built-in sandbox support.
# Uses the official OpenClaw image as base; adds Docker CLI so the gateway
# can spawn sandbox containers via the host Podman socket.

FROM ghcr.io/openclaw/openclaw:2026.3.13-1

USER root

# Install Docker CLI (used by OpenClaw to manage sandbox containers).
# Only the CLI is needed -- the daemon runs on the host via Podman socket.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        docker.io \
        tini \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Install signal-cli native build (no Java required).
# Used by OpenClaw Signal channel for messaging.
RUN SIGNAL_CLI_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} \
        https://github.com/AsamK/signal-cli/releases/latest | sed -e 's/^.*\/v//') \
    && curl -L -o /tmp/signal-cli.tar.gz \
        "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    && tar xf /tmp/signal-cli.tar.gz -C /opt \
    && ln -sf /opt/signal-cli /usr/local/bin/signal-cli \
    && rm /tmp/signal-cli.tar.gz

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
