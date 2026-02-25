.PHONY: help test shell build clean rebuild logs status health

# Default target
.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "Docker Integration Testing - Make Commands"
	@echo "==========================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'

## test: Run all integration tests
test:
	@./run-tests.sh

## shell: Start interactive development shell
shell:
	@./dev-shell.sh

## build: Build Docker images
build:
	@docker compose build

## rebuild: Rebuild Docker images without cache
rebuild:
	@docker compose build --no-cache

## up: Start services in background
up:
	@docker compose up -d

## down: Stop all services
down:
	@docker compose down

## clean: Remove containers, volumes, and networks
clean:
	@docker compose down -v
	@echo "✅ Cleaned up containers, volumes, and networks"

## logs: Follow OpenSearch logs
logs:
	@docker compose logs -f opensearch

## logs-test: Follow test container logs
logs-test:
	@docker compose logs -f test

## status: Show service status
status:
	@docker compose ps

## health: Check OpenSearch health
health:
	@curl -s http://localhost:9200/_cluster/health?pretty || echo "OpenSearch not reachable"

## setup: Initial setup (copy env file)
setup:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Created .env file from template"; \
		echo "💡 Edit .env to customize your setup"; \
	else \
		echo "⚠️  .env already exists"; \
	fi

## verify: Verify Docker configuration
verify:
	@echo "Verifying Docker setup..."
	@docker compose config --quiet && echo "✅ Docker Compose configuration is valid" || echo "❌ Invalid configuration"
	@docker --version
	@docker compose version

## prune: Clean up Docker system (careful!)
prune:
	@echo "⚠️  This will remove all unused Docker resources!"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] && docker system prune -a || echo "Cancelled"

