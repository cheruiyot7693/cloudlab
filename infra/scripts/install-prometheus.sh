#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — Prometheus + Grafana Stack Install
# Installs kube-prometheus-stack via Helm into cloudlab-monitor namespace.
#
# Usage:
#   chmod +x infra/scripts/install-prometheus.sh
#   ./infra/scripts/install-prometheus.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}══ $* ══${NC}"; }

export KUBECONFIG="${HOME}/.kube/config"

# ── Check prerequisites ───────────────────────────────────────────────────────
section "Prerequisites"

command -v kubectl &>/dev/null || error "kubectl not found. Run bootstrap-k3s.sh first."
command -v helm    &>/dev/null || {
  info "Helm not found. Installing..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}
success "kubectl and helm present"

kubectl get namespace cloudlab-monitor &>/dev/null || \
  error "Namespace cloudlab-monitor not found. Run bootstrap-k3s.sh first."

# ── Add Helm repos ────────────────────────────────────────────────────────────
section "Adding Helm Repositories"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
success "Helm repos updated"

# ── Install / Upgrade ─────────────────────────────────────────────────────────
section "Installing kube-prometheus-stack"

helm upgrade --install cloudlab-monitor prometheus-community/kube-prometheus-stack \
  --namespace cloudlab-monitor \
  --values infra/helm/prometheus-values.yaml \
  --timeout 5m \
  --wait

success "Prometheus stack installed"

# ── Verify ────────────────────────────────────────────────────────────────────
section "Verification"

echo ""
info "Pods in cloudlab-monitor:"
kubectl get pods -n cloudlab-monitor

echo ""
success "Prometheus + Grafana installed!"
echo ""
echo -e "${BOLD}Access:${NC}"
echo "  Grafana  → http://localhost:32001  (admin / cloudlab_dev)"
echo "  Note: Change Grafana password before exposing to network"
echo ""
