# This project was developed with assistance from AI tools.
#
# Convenience targets for OpenClaw gateway and sandbox management.

GATEWAY_IMAGE := openclaw-gateway
SANDBOX_IMAGE := openclaw-sandbox:bookworm-slim
CONTAINER := openclaw-gateway

.PHONY: build build-gateway build-sandbox push run stop logs verify chat shell clean fetch-secrets \
        sandbox-list sandbox-explain give help

build: build-gateway build-sandbox ## Build all images (gateway + sandbox)

build-gateway: ## Build the gateway image
	podman build -t $(GATEWAY_IMAGE):latest .

build-sandbox: ## Build the sandbox image
	podman build -t $(SANDBOX_IMAGE) -f Dockerfile.sandbox .

run: ## Start the gateway and proxy
	podman-compose up -d

stop: ## Stop and remove containers (including stale sandboxes)
	@podman ps -a --filter "name=openclaw-sbx" --format "{{.ID}}" | xargs -r podman rm -f 2>/dev/null || true
	podman-compose down

logs: ## Tail gateway logs
	podman-compose logs -f openclaw

verify: ## Run sandbox verification checklist
	bash scripts/verify-sandbox.sh

chat: ## Open the OpenClaw TUI chat interface (waits for healthy gateway)
	@echo "Waiting for gateway to be healthy..."
	@until podman healthcheck run $(CONTAINER) >/dev/null 2>&1; do sleep 2; done
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

give: ## Copy file(s) to workspace/inbox/ (or to=shared for workspace/shared/)
	@if [ -z "$(src)" ]; then echo "Usage: make give src=<file-or-dir> [to=shared]"; exit 1; fi
	@dest="workspace/$(or $(to),inbox)"; \
	mkdir -p "$$dest"; \
	cp -r $(src) "$$dest/"; \
	echo "Copied to $$dest/"

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'
