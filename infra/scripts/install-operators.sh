#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — Install Operators
# Installs: Multus CNI, Containerlab Operator, KubeVirt Operator
#
# Run after bootstrap-k3s.sh and apply-manifests.sh.
#
# Usage:
#   chmod +x infra/scripts/install-operators.sh
#   ./infra/scripts/install-operators.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}══ $* ══${NC}"; }

export KUBECONFIG="${HOME}/.kube/config"

# ── Preflight ─────────────────────────────────────────────────────────────────
section "Preflight"

command -v kubectl &>/dev/null || error "kubectl not found. Run bootstrap-k3s.sh first."
kubectl get nodes &>/dev/null    || error "Cannot reach K3s API. Is K3s running?"
success "K3s reachable"

# Check hardware virtualisation for KubeVirt
VIRT_COUNT=$(egrep -c '(vmx|svm)' /proc/cpuinfo 2>/dev/null || echo 0)
if [[ "$VIRT_COUNT" -gt 0 ]]; then
  success "Hardware virtualisation available (KubeVirt will use KVM)"
  KUBEVIRT_EMULATION=false
else
  warn "No hardware virtualisation detected — KubeVirt will use software emulation"
  warn "QEMU-based labs (Cisco IOSv) will be very slow in emulation mode"
  KUBEVIRT_EMULATION=true
fi

# ── Multus CNI ────────────────────────────────────────────────────────────────
section "Installing Multus CNI"

info "Applying Multus CNI manifests..."
kubectl apply -f infra/k8s/multus-cni.yaml

info "Waiting for Multus DaemonSet to be ready..."
kubectl rollout status daemonset/kube-multus-ds -n kube-system --timeout=120s
success "Multus CNI installed"

# Verify NetworkAttachmentDefinition CRD is available
kubectl get crd network-attachment-definitions.k8s.cni.cncf.io &>/dev/null && \
  success "NetworkAttachmentDefinition CRD registered" || \
  warn "NAD CRD not yet visible — may need a moment"

# ── Containerlab Operator ─────────────────────────────────────────────────────
section "Installing Containerlab Operator"

info "Applying Containerlab operator manifests..."
kubectl apply -f infra/k8s/containerlab-operator.yaml

info "Waiting for Containerlab CRD to be established..."
timeout 60 bash -c 'until kubectl get crd containerlabs.clabs.nokia.com &>/dev/null; do sleep 3; done'
success "ContainerLab CRD registered"

info "Waiting for operator deployment..."
kubectl rollout status deployment/containerlab-operator \
  -n cloudlab-system --timeout=120s 2>/dev/null || \
  warn "Operator pod not ready yet — image may still be pulling"

success "Containerlab operator installed"

# ── KubeVirt ─────────────────────────────────────────────────────────────────
section "Installing KubeVirt"

# Patch emulation setting based on hardware detection
if [[ "$KUBEVIRT_EMULATION" == "true" ]]; then
  info "Patching KubeVirt CR for software emulation mode..."
  sed -i 's/useEmulation: false/useEmulation: true/' infra/k8s/kubevirt-operator.yaml
fi

# Install KubeVirt operator via official manifests
KUBEVIRT_VERSION="v1.2.0"
info "Applying KubeVirt operator v${KUBEVIRT_VERSION}..."

kubectl apply -f \
  "https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-operator.yaml"

info "Applying KubeVirt CR..."
kubectl apply -f \
  "https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-cr.yaml"

info "Waiting for KubeVirt to be ready (this takes 3-5 minutes)..."
kubectl wait --for=condition=Available \
  kubevirt/kubevirt \
  -n kubevirt \
  --timeout=300s || warn "KubeVirt not ready yet — check: kubectl get pods -n kubevirt"

success "KubeVirt installed"

# ── virtctl ───────────────────────────────────────────────────────────────────
section "Installing virtctl"

if ! command -v virtctl &>/dev/null; then
  info "Downloading virtctl CLI..."
  ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
  curl -sL \
    "https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/virtctl-${KUBEVIRT_VERSION}-linux-${ARCH}" \
    -o /usr/local/bin/virtctl
  chmod +x /usr/local/bin/virtctl
  success "virtctl installed to /usr/local/bin/virtctl"
else
  success "virtctl already installed: $(virtctl version --client 2>/dev/null | head -1)"
fi

# ── Verification ──────────────────────────────────────────────────────────────
section "Verification"

echo ""
info "Multus pods:"
kubectl get pods -n kube-system -l name=multus

echo ""
info "Containerlab operator:"
kubectl get pods -n cloudlab-system -l app=containerlab-operator

echo ""
info "KubeVirt components:"
kubectl get pods -n kubevirt 2>/dev/null || warn "KubeVirt pods still starting"

echo ""
info "CRDs registered:"
kubectl get crd | grep -E "clabs|kubevirt" || true

echo ""
success "Operators installation complete!"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  Verify:        make cluster-status"
echo "  Test clab CRD: kubectl get clab -A"
echo "  Test kubevirt: kubectl get vms -A"
echo "  Phase 0.4b:    Deploy first FRR topology → Phase 2.1"
echo ""
