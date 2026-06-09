#!/usr/bin/env bash
# =============================================================================
# CloudLab — Phase 0.3 Master Bootstrap
# Runs all Phase 0.3 steps in order:
#   1. Apply monitoring RBAC
#   2. Install Longhorn
#   3. Install metrics-server + Prometheus stack
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
heading() { echo -e "\n${BOLD}$*${NC}"; }

heading "━━━ CloudLab Phase 0.3 Bootstrap ━━━"
echo "  K3s cluster + Longhorn + Metrics-server + Prometheus"
echo ""

# 1. RBAC for monitoring namespace
heading "Step 1/3 — Namespace RBAC"
kubectl apply -f "${SCRIPT_DIR}/../namespaces/monitoring-rbac.yaml"
info "Monitoring namespace and RBAC applied"

# 2. Longhorn
heading "Step 2/3 — Longhorn Storage Provisioner"
chmod +x "${SCRIPT_DIR}/install-longhorn.sh"
"${SCRIPT_DIR}/install-longhorn.sh"

# 3. Monitoring stack
heading "Step 3/3 — Metrics-server + Prometheus + Grafana"
chmod +x "${SCRIPT_DIR}/install-monitoring.sh"
"${SCRIPT_DIR}/install-monitoring.sh"

# Summary
echo ""
echo -e "${BOLD}━━━ Phase 0.3 Complete ━━━${NC}"
echo ""
echo "  Commits to make:"
echo "    git add infra/"
echo "    git commit -m 'infra: k3s bootstrap script'"
echo "    git commit -m 'infra: namespace and RBAC manifests'"
echo "    git commit -m 'infra: longhorn storage class config'"
echo "    git commit -m 'infra: prometheus and grafana helm chart'"
echo ""
echo "  Verify:"
echo "    kubectl get storageclass"
echo "    kubectl top nodes"
echo "    kubectl get pods -n cloudlab-monitoring"
echo ""
echo "  Next: Phase 0.4 — Containerlab + KubeVirt + Multus CNI"
