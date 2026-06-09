#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — Cluster Health Check
# Run anytime to verify the cluster state.
#
# Usage:
#   ./infra/scripts/verify-cluster.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
fail() { echo -e "  ${RED}✗${NC}  $*"; FAILED=$((FAILED+1)); }
warn() { echo -e "  ${YELLOW}!${NC}  $*"; }
section() { echo -e "\n${BOLD}── $* ──${NC}"; }

export KUBECONFIG="${HOME}/.kube/config"
FAILED=0

echo -e "\n${BOLD}CloudLab Cluster Verification${NC}"
echo "=============================="

# ── K3s running ───────────────────────────────────────────────────────────────
section "K3s Service"
if systemctl is-active --quiet k3s; then
  ok "k3s service is running"
else
  fail "k3s service is NOT running — start with: sudo systemctl start k3s"
fi

# ── Node ready ────────────────────────────────────────────────────────────────
section "Node Status"
if kubectl get nodes | grep -q " Ready"; then
  NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
  ok "Node ${NODE} is Ready"
else
  fail "No Ready nodes found"
fi

# ── Namespaces ────────────────────────────────────────────────────────────────
section "CloudLab Namespaces"
for ns in cloudlab-system cloudlab-labs cloudlab-monitor; do
  if kubectl get namespace "$ns" &>/dev/null; then
    ok "Namespace: $ns"
  else
    fail "Missing namespace: $ns — run bootstrap-k3s.sh"
  fi
done

# ── RBAC ─────────────────────────────────────────────────────────────────────
section "RBAC"
if kubectl get clusterrole cloudlab-lab-manager &>/dev/null; then
  ok "ClusterRole: cloudlab-lab-manager"
else
  fail "Missing ClusterRole: cloudlab-lab-manager"
fi
if kubectl get clusterrolebinding cloudlab-backend-lab-manager &>/dev/null; then
  ok "ClusterRoleBinding: cloudlab-backend-lab-manager"
else
  fail "Missing ClusterRoleBinding"
fi

# ── Resource Quotas ───────────────────────────────────────────────────────────
section "Resource Quotas"
for ns in cloudlab-labs cloudlab-system cloudlab-monitor; do
  if kubectl get resourcequota -n "$ns" 2>/dev/null | grep -q quota; then
    ok "ResourceQuota in $ns"
  else
    warn "No ResourceQuota in $ns (run: kubectl apply -f infra/k8s/resource-quotas.yaml)"
  fi
done

# ── Local Registry ────────────────────────────────────────────────────────────
section "Local Image Registry"
if kubectl get deployment local-registry -n cloudlab-system &>/dev/null; then
  READY=$(kubectl get deployment local-registry -n cloudlab-system \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  if [[ "${READY}" == "1" ]]; then
    ok "Local registry running on :32000"
  else
    warn "Local registry pod not ready yet (give it 30s)"
  fi
else
  warn "Local registry not deployed (run: kubectl apply -f infra/k8s/local-registry.yaml)"
fi

# ── Resource usage ────────────────────────────────────────────────────────────
section "Resource Usage"
if kubectl top nodes &>/dev/null 2>&1; then
  kubectl top nodes
else
  warn "metrics-server not ready yet — resource usage unavailable"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================="
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed! Cluster is healthy.${NC}"
else
  echo -e "${RED}${BOLD}${FAILED} check(s) failed. See above.${NC}"
  exit 1
fi
echo ""
