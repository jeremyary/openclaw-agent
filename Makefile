# This project was developed with assistance from AI tools.
#
# Convenience targets for OpenClaw sandbox management.

# Force podman-compose over legacy docker-compose
export PODMAN_COMPOSE_PROVIDER := podman-compose

IMAGE := quay.io/jary/openclaw-sandbox
TAG := latest

.PHONY: build push run stop logs verify chat shell clean fetch-secrets

build: ## Build the container image
	podman build -t $(IMAGE):$(TAG) .

push: ## Push image to quay.io/jary
	podman push $(IMAGE):$(TAG)

run: ## Start the container
	podman compose up -d

stop: ## Stop and remove the container
	podman compose down

logs: ## Tail container logs
	podman compose logs -f openclaw

verify: ## Run the 10-point sandbox verification checklist
	bash scripts/verify-sandbox.sh

chat: ## Open the OpenClaw TUI chat interface
	podman exec -it openclaw-sandbox bash -c 'exec openclaw tui --token "$$(cat /secrets/gateway_token)"'

shell: ## Interactive shell in the container
	podman exec -it openclaw-sandbox bash

clean: ## Remove container, volumes, and image
	podman compose down -v --rmi local

fetch-secrets: ## Fetch secrets from Vault to /tmp/openclaw-secrets/
	bash scripts/fetch-secrets.sh

give: ## Copy file(s) to workspace with agent ownership: make give src=myfile.md
	@if [ -z "$(src)" ]; then echo "Usage: make give src=<file-or-dir>"; exit 1; fi
	sudo cp -r $(src) workspace/
	sudo chown -R 100999:100999 $(addprefix workspace/,$(notdir $(src)))

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'
