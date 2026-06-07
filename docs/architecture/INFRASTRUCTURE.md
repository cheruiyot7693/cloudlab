# CloudLab Platform — Infrastructure Architecture

## Local Development Cluster (8GB RAM)

```
┌─────────────────────────────────────────────────────────────┐
│                    Kali Linux Host                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  K3s Cluster                         │  │
│  │                                                      │  │
│  │  ┌─────────────────┐  ┌─────────────────┐           │  │
│  │  │ cloudlab-system │  │ cloudlab-monitor │           │  │
│  │  │                 │  │                 │           │  │
│  │  │ • backend API   │  │ • Prometheus    │           │  │
│  │  │ • celery worker │  │ • Grafana       │           │  │
│  │  │ • keycloak      │  │ • Loki          │           │  │
│  │  │ • local-registry│  │                 │           │  │
│  │  │                 │  │ Quota: 1GB RAM  │           │  │
│  │  │ Quota: 3GB RAM  │  └─────────────────┘           │  │
│  │  └─────────────────┘                                │  │
│  │                                                      │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │              cloudlab-labs                  │    │  │
│  │  │                                             │    │  │
│  │  │  ns: lab-<user-id>-<lab-id>                │    │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │  │
│  │  │  │ frr-r1   │  │ frr-r2   │  │ frr-r3   │  │    │  │
│  │  │  │ 128Mi RAM│  │ 128Mi RAM│  │ 128Mi RAM│  │    │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘  │    │  │
│  │  │                                             │    │  │
│  │  │  Quota: 5GB RAM total / 50 pods             │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Docker Compose (dev platform)             │   │
│  │  postgres │ redis │ keycloak │ mailhog │ wetty      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## RAM Budget (8GB)

| Component | Reserved | Notes |
|---|---|---|
| OS + Kali desktop | ~1.5GB | baseline |
| K3s system | ~300MB | lean config, no Traefik |
| Docker Compose stack | ~800MB | postgres, redis, keycloak, etc |
| cloudlab-system (K8s) | up to 3GB | backend, celery, registry |
| cloudlab-monitor (K8s) | up to 1GB | prometheus, grafana |
| cloudlab-labs (K8s) | up to 5GB | actual lab containers |
| **Total cap** | **~8GB** | enforced via ResourceQuotas |

Lab capacity on 8GB:
- FRR/VyOS containers: ~128MB each → ~15 nodes simultaneously
- A typical 3-5 node OSPF/BGP lab: well within budget
- 20-node MPLS fabric: not possible locally — needs 16GB+

## Namespace Strategy

```
cloudlab-system       → platform services (stable, long-running)
cloudlab-labs         → all user labs (dynamic, short-lived namespaces)
  └── lab-<uid>-<lid> → one child namespace per running lab
cloudlab-monitor      → observability stack
```

## Port Map (local dev)

| Service | Port | Access |
|---|---|---|
| K3s API server | 6443 | kubectl |
| Frontend (Docker) | 3000 | browser |
| Backend API (Docker) | 8000 | browser / curl |
| Keycloak (Docker) | 8080 | browser |
| Mailhog (Docker) | 8025 | browser |
| Wetty SSH (Docker) | 3001 | browser |
| Grafana (K8s NodePort) | 32001 | browser |
| Local Registry (K8s NodePort) | 32000 | docker push |
