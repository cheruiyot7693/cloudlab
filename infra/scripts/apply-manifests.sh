#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — Apply All K8s Manifests
# Applies namespaces, RBAC, quotas, registry, and metrics-server.
# Run after bootstrap-k3s.sh.
#
# Usage:
#   ./infra/scripts/apply-manifests.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
section() { echo -e "\n${BOLD}══ $* ══${NC}"; }

export KUBECONFIG="${HOME}/.kube/config"

section "Namespaces"
kubectl apply -f infra/k8s/namespaces.yaml
success "Namespaces applied"

section "RBAC"
kubectl apply -f infra/k8s/rbac.yaml
success "RBAC applied"

section "Resource Quotas"
kubectl apply -f infra/k8s/resource-quotas.yaml
success "Resource quotas applied"

section "Local Registry"
kubectl apply -f infra/k8s/local-registry.yaml
success "Local registry applied"

section "Metrics Server"
kubectl apply -f infra/k8s/metrics-server.yaml
success "Metrics server applied"

section "Waiting for metrics-server"
kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s
success "Metrics server ready"

echo ""
success "All manifests applied. Run: make k3s-verify"
echo ""
info "Test kubectl top:"
echo "  kubectl top nodes"
echo "  kubectl top pods -A"
echo ""
info "Test namespace provisioner:"
echo "  python3 infra/scripts/namespace_provisioner.py --list"
echo "  python3 infra/scripts/namespace_provisioner.py --create --user testuser --lab testlab01"
