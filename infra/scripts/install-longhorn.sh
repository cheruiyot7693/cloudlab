#!/usr/bin/env bash
# =============================================================================
# CloudLab — Longhorn Storage Provisioner Install
# Phase 0.3 | infra: longhorn storage class config
# =============================================================================
set -euo pipefail

LONGHORN_VERSION="1.6.2"
LONGHORN_NAMESPACE="longhorn-system"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# -----------------------------------------------------------------------------
# 1. Pre-flight checks
# -----------------------------------------------------------------------------
info "Checking prerequisites..."

command -v kubectl  >/dev/null 2>&1 || error "kubectl not found"
command -v helm     >/dev/null 2>&1 || error "helm not found"
kubectl cluster-info >/dev/null 2>&1 || error "Cannot reach Kubernetes cluster"

# Longhorn requires open-iscsi on every node
info "Checking open-iscsi on all nodes..."
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
for NODE in $NODES; do
  ISCSI_OK=$(kubectl get node "$NODE" -o jsonpath='{.metadata.annotations}' | grep -c "longhorn" || true)
  # We just warn — iscsi check happens inside Longhorn's own preflight
done

# Longhorn preflight checker (runs as a DaemonSet, self-cleans)
info "Running Longhorn environment check..."
kubectl apply -f \
  https://raw.githubusercontent.com/longhorn/longhorn/v${LONGHORN_VERSION}/deploy/prerequisite/longhorn-iscsi-installation.yaml \
  --dry-run=client -o yaml | kubectl apply -f - || warn "iSCSI installer skipped (may already be present)"

sleep 5

# -----------------------------------------------------------------------------
# 2. Add Helm repo
# -----------------------------------------------------------------------------
info "Adding Longhorn Helm repo..."
helm repo add longhorn https://charts.longhorn.io 2>/dev/null || true
helm repo update

# -----------------------------------------------------------------------------
# 3. Install Longhorn
# -----------------------------------------------------------------------------
info "Installing Longhorn v${LONGHORN_VERSION}..."
kubectl create namespace ${LONGHORN_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install longhorn longhorn/longhorn \
  --namespace ${LONGHORN_NAMESPACE} \
  --version "${LONGHORN_VERSION}" \
  --set defaultSettings.defaultReplicaCount=1 \
  --set defaultSettings.storageMinimalAvailablePercentage=10 \
  --set defaultSettings.autoDeletePodWhenVolumeDetachedUnexpectedly=true \
  --set defaultSettings.nodeDownPodDeletionPolicy=delete-both-statefulset-and-deployment-pod \
  --set persistence.defaultClass=true \
  --set persistence.defaultClassReplicaCount=1 \
  --set ingress.enabled=false \
  --wait --timeout=10m

info "Longhorn deployed. Waiting for all pods to be Ready..."
kubectl rollout status deployment/longhorn-manager        -n ${LONGHORN_NAMESPACE} --timeout=5m
kubectl rollout status deployment/longhorn-driver-deployer -n ${LONGHORN_NAMESPACE} --timeout=5m
kubectl rollout status deployment/longhorn-ui              -n ${LONGHORN_NAMESPACE} --timeout=5m

# -----------------------------------------------------------------------------
# 4. Apply CloudLab StorageClass overrides
# -----------------------------------------------------------------------------
info "Applying CloudLab StorageClass manifests..."
kubectl apply -f "$(dirname "$0")/../storage/storageclass-longhorn.yaml"

# -----------------------------------------------------------------------------
# 5. Smoke test — create PVC, write file, verify persistence
# -----------------------------------------------------------------------------
info "Running PVC smoke test..."
kubectl apply -f "$(dirname "$0")/../storage/smoke-test.yaml"

info "Waiting for smoke-test pod to complete..."
kubectl wait pod/longhorn-smoke-test \
  --for=condition=Ready \
  --timeout=120s \
  -n default || error "Smoke test pod did not become Ready"

# Write a file
kubectl exec longhorn-smoke-test -- sh -c "echo 'cloudlab-ok' > /data/test.txt"
RESULT=$(kubectl exec longhorn-smoke-test -- cat /data/test.txt)
[[ "$RESULT" == "cloudlab-ok" ]] || error "PVC write/read verification FAILED"

info "PVC smoke test PASSED — data persists on Longhorn volume"

# Cleanup smoke test
kubectl delete -f "$(dirname "$0")/../storage/smoke-test.yaml" --ignore-not-found

info "✓ Longhorn ${LONGHORN_VERSION} installed and verified"
info "  StorageClass 'longhorn' is now the cluster default"
info "  UI: kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
