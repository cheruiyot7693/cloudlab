# ☁️ CloudLab Platform

> **Network labs, ready to use. No setup headaches.**

CloudLab is a managed, hosted cloud lab environment that aggregates pre-deployed network topologies — routers, switches, firewalls, and multi-vendor NOS images — and presents them as a one-click, ready-to-run lab catalog.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/YOUR_ORG/cloudlab/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/cloudlab/actions/workflows/ci.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## 🚀 What is CloudLab?

Network engineers spend days provisioning VMs, installing NOS images, and wiring topologies before a single lab can run. CloudLab eliminates all of that:

- **Boot any lab in < 3 minutes** from a growing topology catalog
- **Pay only for active lab time** — auto-pause when idle
- **Multi-vendor NOS**: FRRouting, VyOS, Arista cEOS, Cisco IOSv, Juniper vSRX
- **Browser SSH** — no client, no VPN, instant node access
- **Team workspaces** — share labs, snapshot configs, collaborate in real time

---

## 📁 Repository Structure

```
cloudlab/
├── infra/                  # Kubernetes manifests, Helm charts, Terraform
│   ├── scripts/            # Cluster bootstrap and ops scripts
│   ├── k8s/                # Raw Kubernetes manifests
│   ├── helm/               # Helm chart values and overrides
│   └── terraform/          # Cloud provider infrastructure
├── backend/                # FastAPI application
│   ├── app/                # Application source code
│   └── tests/              # Unit and integration tests
├── frontend/               # React + TypeScript application
│   ├── src/
│   └── public/
├── lab-catalog/            # Containerlab topology YAML files
│   ├── topologies/         # Lab topology definitions
│   └── images/             # NOS image metadata and pull scripts
├── docs/                   # Project documentation
│   ├── architecture/       # System architecture docs
│   ├── api/                # API specifications
│   └── runbooks/           # Operational runbooks
└── .github/                # GitHub Actions and templates
    ├── workflows/
    ├── ISSUE_TEMPLATE/
    └── PULL_REQUEST_TEMPLATE/
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Orchestration | Kubernetes (K3s dev / EKS prod) |
| Lab Engine | Containerlab + KubeVirt |
| Networking | Multus CNI + SR-IOV |
| Storage | Longhorn |
| API Backend | FastAPI (Python 3.12) |
| Task Queue | Celery + Redis |
| Frontend | React 18 + TypeScript + Tailwind CSS |
| Auth | Keycloak (OAuth2 / OIDC) |
| Billing | Stripe + custom metering service |
| Terminal | Wetty (xterm.js over WebSocket) |
| Observability | Prometheus + Grafana + Loki |
| CI/CD | GitHub Actions |

---

## ⚡ Quick Start (Local Dev)

### Prerequisites

- Docker Desktop or Docker Engine + Docker Compose
- Node.js 20+
- Python 3.12+
- `kubectl` + `helm`

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_ORG/cloudlab.git
cd cloudlab
```

### 2. Start local development environment

```bash
docker compose up -d
```

This starts:
- PostgreSQL (port 5432)
- Redis (port 6379)
- Keycloak (port 8080)
- FastAPI backend (port 8000)
- React frontend (port 3000)

### 3. Run backend tests

```bash
cd backend
pip install -r requirements-dev.txt
pytest
```

### 4. Run frontend

```bash
cd frontend
npm install
npm run dev
```

---

## 🗺️ Development Roadmap

| Phase | Description | Status |
|---|---|---|
| 0 | Repo bootstrap, CI/CD, K8s skeleton | 🔄 In Progress |
| 1 | Backend API, auth, lab lifecycle | ⏳ Planned |
| 2 | Lab catalog, topology engine | ⏳ Planned |
| 3 | React frontend, browser SSH | ⏳ Planned |
| 4 | Billing engine (Stripe) | ⏳ Planned |
| 5 | Team workspaces, collaboration | ⏳ Planned |
| 6 | Hardening, observability, launch | ⏳ Planned |

See the full [White Paper & Roadmap](docs/architecture/WHITEPAPER.md) for detail.

---

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR. We follow [Conventional Commits](https://www.conventionalcommits.org/) and require passing CI on all PRs.

---

## 📄 License

[MIT](LICENSE) © 2026 CloudLab Platform
