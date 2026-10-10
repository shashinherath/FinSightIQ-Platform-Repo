# ==============================================================================
# FinSightIQ Platform — Developer Makefile
# ==============================================================================
# Self-documenting Makefile for local infrastructure orchestration.
# Run 'make help' or 'make' to view available targets.
# ==============================================================================

.DEFAULT_GOAL := help
.PHONY: help bootstrap up up-monitoring up-all down ps logs build provision migrate seed test-all reset

COMPOSE := docker compose
BASH := bash

help: ## Show this help message
	@echo "=============================================================================="
	@echo "FinSightIQ Platform Orchestration Commands"
	@echo "=============================================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="

bootstrap: ## Synchronize and checkout sibling repositories defined in workspace.lock
	@$(BASH) bootstrap.sh

up: ## Start core infrastructure containers (PostgreSQL, Redis, RabbitMQ)
	@$(COMPOSE) up -d postgres redis rabbitmq

up-monitoring: ## Start core infrastructure plus Prometheus and Grafana
	@$(COMPOSE) --profile monitoring up -d

up-all: ## Start all platform services, infrastructure, and monitoring
	@$(COMPOSE) --profile monitoring --profile services up -d

down: ## Stop all running containers without destroying data volumes (non-destructive)
	@$(COMPOSE) down

ps: ## View current container status and health checks
	@$(COMPOSE) ps

logs: ## Tail and follow logs from all active containers
	@$(COMPOSE) logs -f

build: ## Build platform container images
	@$(COMPOSE) build

provision: ## Provision PostgreSQL logical databases (usersdb, marketdb, predictiondb, etc.)
	@$(BASH) migrate/provision.sh

migrate: ## Run Flyway migrations across sibling service repositories
	@$(BASH) migrate/migrate.sh

seed: ## Seed demo development data (users, market symbols) into migrated databases
	@$(BASH) seed/seed.sh

test-all: ## Run platform E2E and health tests
	@cd tests/e2e && npm test

reset: ## DESTRUCTIVE: Stop containers and delete all persistent data volumes
	@echo "WARNING: This will permanently wipe all local database, cache, and queue volumes!"
	@read -p "Type 'yes' to confirm volume deletion: " confirm && [ "$$confirm" = "yes" ] || (echo "Reset cancelled." && exit 1)
	@$(COMPOSE) down -v
	@echo "Platform reset complete. Clean state restored."
