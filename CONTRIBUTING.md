# Contributing to CloudLab Platform

Thank you for your interest in contributing! This guide explains how to work with the codebase and get your changes merged.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Branch Strategy](#branch-strategy)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [CI Requirements](#ci-requirements)
- [Code Style](#code-style)

---

## Code of Conduct

Be respectful, constructive, and collaborative. We are building something useful — keep discussions focused on the work.

---

## Getting Started

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/YOUR_USERNAME/cloudlab.git`
3. **Set upstream**: `git remote add upstream https://github.com/YOUR_ORG/cloudlab.git`
4. **Create a branch** from `main`: `git checkout -b feat/your-feature-name`
5. Make your changes, commit, push, and open a PR against `main`

---

## Branch Strategy

| Branch pattern | Purpose |
|---|---|
| `main` | Production-ready code. Protected. Requires PR + review. |
| `feat/<name>` | New features |
| `fix/<name>` | Bug fixes |
| `infra/<name>` | Infrastructure and Kubernetes changes |
| `docs/<name>` | Documentation only |
| `chore/<name>` | Maintenance, dependency updates |
| `ci/<name>` | CI/CD pipeline changes |
| `security/<name>` | Security-related changes |

**Never push directly to `main`.** All changes go through a PR with at least one approval.

---

## Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/). Every commit message must have the format:

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

### Types

| Type | When to use |
|---|---|
| `feat` | A new feature |
| `fix` | A bug fix |
| `chore` | Maintenance, build, dependency updates |
| `docs` | Documentation only |
| `test` | Adding or fixing tests |
| `infra` | Kubernetes, Helm, Terraform changes |
| `security` | Security fixes or hardening |
| `ci` | CI/CD pipeline changes |
| `refactor` | Code refactor with no behavior change |
| `perf` | Performance improvements |

### Scopes

Use the directory or component name: `backend`, `frontend`, `infra`, `catalog`, `billing`, `auth`, `docs`, `ci`.

### Examples

```bash
feat(backend): add lab lifecycle pause endpoint
fix(frontend): resolve websocket reconnect on tab focus
infra: add containerlab operator helm chart
test(backend): add integration tests for lab provisioner
docs: update architecture diagram for phase 1
ci: add topology yaml validation step to pr workflow
chore(backend): upgrade fastapi to 0.111.0
security: enforce network policies for lab namespaces
```

---

## Pull Request Process

1. **One concern per PR** — keep PRs focused. Large PRs are hard to review.
2. **Fill out the PR template** completely.
3. **Link the relevant issue** using `Closes #<issue_number>` in the PR description.
4. **Ensure CI passes** — lint, tests, and topology validation must all be green.
5. **Request review** from at least one maintainer.
6. **Do not merge your own PR** — always get a review.
7. **Squash merge** is preferred for feature branches to keep `main` history clean.

---

## CI Requirements

All PRs must pass:

- **Lint**: Python (Black + isort + flake8), TypeScript (ESLint + Prettier)
- **Tests**: Backend unit tests (`pytest`), frontend tests (`vitest`)
- **Topology validation**: All `.clab.yml` files in `lab-catalog/` must pass schema validation
- **Docker build**: Both `backend` and `frontend` images must build successfully

---

## Code Style

### Python (backend)

- Formatter: **Black** (line length 88)
- Import sorter: **isort**
- Linter: **flake8**
- Type hints: required on all public functions
- Docstrings: Google style

```bash
# Format
black backend/
isort backend/

# Lint
flake8 backend/
```

### TypeScript (frontend)

- Formatter: **Prettier**
- Linter: **ESLint** with TypeScript rules
- Strict TypeScript: enabled

```bash
# Format + lint
cd frontend
npm run lint
npm run format
```

### Infrastructure (Kubernetes / Helm)

- YAML files must pass `kubectl --dry-run=client` validation
- Helm charts must pass `helm lint`
- All secrets must be referenced from environment variables or Vault — never hardcoded

---

## Questions?

Open a Discussion on GitHub or reach out in the team Slack channel `#cloudlab-dev`.
