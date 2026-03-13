# This project was developed with assistance from AI tools.
#
# Convenience targets for OpenClaw gateway and sandbox management.

GATEWAY_IMAGE := openclaw-gateway
SANDBOX_IMAGE := openclaw-sandbox:bookworm-slim
CONTAINER := openclaw-gateway

.PHONY: build build-sandbox push run stop logs verify chat shell clean fetch-secrets \
        sandbox-list sandbox-explain give help

build: ## Build the gateway image
	podman build -t $(GATEWAY_IMAGE):latest .

build-sandbox: ## Build the sandbox image from official Dockerfile.sandbox
	@if [ ! -f Dockerfile.sandbox ]; then \
		echo "Fetching Dockerfile.sandbox from OpenClaw repo..."; \
		curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/Dockerfile.sandbox \
			-o Dockerfile.sandbox; \
	fi
	podman build -t $(SANDBOX_IMAGE) -f Dockerfile.sandbox .

run: ## Start the gateway and proxy
	podman-compose up -d

stop: ## Stop and remove containers
	podman-compose down

logs: ## Tail gateway logs
	podman-compose logs -f openclaw

verify: ## Run sandbox verification checklist
	bash scripts/verify-sandbox.sh

chat: ## Open the OpenClaw TUI chat interface
	podman exec -it $(CONTAINER) bash -c 'exec openclaw tui --token "$$(cat /secrets/gateway_token)"'

shell: ## Interactive shell in the gateway container
	podman exec -it $(CONTAINER) bash

clean: ## Remove containers, volumes, and images
	podman-compose down -v --rmi local

fetch-secrets: ## Fetch secrets from Vault to /tmp/openclaw-secrets/
	bash scripts/fetch-secrets.sh

sandbox-list: ## List active sandbox containers
	podman exec $(CONTAINER) openclaw sandbox list

sandbox-explain: ## Show sandbox configuration details
	podman exec $(CONTAINER) openclaw sandbox explain

give: ## Copy file(s) to workspace: make give src=myfile.md
	@if [ -z "$(src)" ]; then echo "Usage: make give src=<file-or-dir>"; exit 1; fi
	cp -r $(src) workspace/

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'
