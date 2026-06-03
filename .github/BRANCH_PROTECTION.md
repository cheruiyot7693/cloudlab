# Branch Protection Configuration

This file documents the branch protection rules to apply on GitHub.
Apply these via: **Settings → Branches → Add rule** for the `main` branch.

## Rules for `main`

```
Branch name pattern: main

✅ Require a pull request before merging
  ✅ Require approvals: 1
  ✅ Dismiss stale pull request approvals when new commits are pushed
  ✅ Require review from Code Owners

✅ Require status checks to pass before merging
  ✅ Require branches to be up to date before merging
  Required status checks:
    - Lint Python (Black + isort + flake8)
    - Lint Frontend (ESLint + Prettier)
    - Backend Tests (pytest)
    - Frontend Tests (Vitest)
    - Validate Lab Topologies
    - Docker Build Check

✅ Require conversation resolution before merging

✅ Do not allow bypassing the above settings

❌ Allow force pushes
❌ Allow deletions
```

## CODEOWNERS

See .github/CODEOWNERS for ownership assignments.
```
# Global owners
*                   @cloudlab-maintainers

# Infrastructure
infra/              @cloudlab-infra

# Backend
backend/            @cloudlab-backend

# Frontend
frontend/           @cloudlab-frontend

# Lab catalog — all topology additions need a review
lab-catalog/        @cloudlab-maintainers

# Security-sensitive files
.github/workflows/  @cloudlab-maintainers
SECURITY.md         @cloudlab-maintainers
```
