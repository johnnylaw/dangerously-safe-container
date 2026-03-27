.PHONY: help build run shell root-shell clean clean-config pull version

COMPOSE_FILE := $(CURDIR)/docker-compose.yml
IMAGE        := dangerously-safe-container:latest
WORKSPACE    ?= $(CURDIR)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

build: ## Build (or rebuild) the Docker image
	docker compose -f $(COMPOSE_FILE) build --pull

run: ## Run claude --dangerously-skip-permissions (set WORKSPACE= to override mount)
	WORKSPACE_DIR=$(WORKSPACE) ./run.sh

shell: ## Open a bash shell inside the container
	WORKSPACE_DIR=$(WORKSPACE) docker compose -f $(COMPOSE_FILE) \
	  run --rm --entrypoint bash claude -l

root-shell: ## Open a root shell inside the container (for debugging)
	WORKSPACE_DIR=$(WORKSPACE) docker compose -f $(COMPOSE_FILE) \
	  run --rm --user root --entrypoint bash claude -l

clean: ## Remove the image and named volumes
	docker compose -f $(COMPOSE_FILE) down --rmi local --volumes --remove-orphans 2>/dev/null || true
	docker image rm $(IMAGE) 2>/dev/null || true

clean-config: ## Delete the persistent Claude config volume (resets history/settings)
	@echo "This will delete all Claude history, config, and sessions stored in the container."
	@echo "Your workspace files on the host are NOT affected."
	@read -p "Continue? [y/N] " ans && [ "$$ans" = "y" ] || exit 0
	docker volume rm dangerously-safe-claude-config 2>/dev/null || true

pull: ## Pull latest base image and rebuild without cache
	docker pull node:22-bookworm-slim
	docker compose -f $(COMPOSE_FILE) build --no-cache

version: ## Show the Claude Code version installed in the image
	docker compose -f $(COMPOSE_FILE) run --rm --entrypoint claude claude --version
