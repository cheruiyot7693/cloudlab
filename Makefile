.PHONY: help up down logs ps shell-backend shell-frontend test lint format validate-topologies clean

# Default target
help:
	@echo ""
	@echo "CloudLab Platform — Dev Commands"
	@echo "=================================="
	@echo "  make up                Start all services (docker compose)"
	@echo "  make down              Stop all services"
	@echo "  make logs              Follow all service logs"
	@echo "  make ps                Show running containers"
	@echo "  make shell-backend     Shell into backend container"
	@echo "  make shell-frontend    Shell into frontend container"
	@echo "  make test              Run all tests"
	@echo "  make lint              Run all linters"
	@echo "  make format            Auto-format Python and TS code"
	@echo "  make validate-topologies  Validate all topology YAML files"
	@echo "  make clean             Remove volumes and containers"
	@echo ""

up:
	docker compose up -d
	@echo ""
	@echo "Services:"
	@echo "  Frontend   → http://localhost:3000"
	@echo "  Backend    → http://localhost:8000"
	@echo "  API Docs   → http://localhost:8000/docs"
	@echo "  Keycloak   → http://localhost:8080"
	@echo "  Mailhog    → http://localhost:8025"
	@echo "  Wetty SSH  → http://localhost:3001"
	@echo ""

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

shell-backend:
	docker compose exec backend bash

shell-frontend:
	docker compose exec frontend sh

test:
	@echo "── Backend tests ──────────────────────────────────────────"
	cd backend && pip install -q -r requirements-dev.txt && pytest tests/ -v
	@echo ""
	@echo "── Frontend tests ─────────────────────────────────────────"
	cd frontend && npm run test:run

lint:
	@echo "── Python lint ────────────────────────────────────────────"
	cd backend && black --check . && isort --check-only . && flake8 .
	@echo "── TypeScript lint ────────────────────────────────────────"
	cd frontend && npm run lint && npm run format:check

format:
	@echo "── Format Python ──────────────────────────────────────────"
	cd backend && black . && isort .
	@echo "── Format TypeScript ──────────────────────────────────────"
	cd frontend && npm run format

validate-topologies:
	python3 lab-catalog/scripts/validate_topologies.py

install-hooks:
	pip install pre-commit
	pre-commit install
	@echo "Pre-commit hooks installed."

clean:
	docker compose down -v --remove-orphans
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
