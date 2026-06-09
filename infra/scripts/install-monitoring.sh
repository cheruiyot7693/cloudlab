#!/usr/bin/env bash
# =============================================================================
# CloudLab — Metrics-server + Prometheus Stack Install
# Phase 0.3 | infra: prometheus and grafana helm chart
# =============================================================================
set -euo pipefail

METRICS_SERVER_VERSION="3.12.1"
KUBE_PROM_VERSION="58.7.2"
MONITORING_NS="cloudlab-monitoring"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
command -v helm    >/dev/null 2>&1 || error "helm not found"
kubectl cluster-info >/dev/null 2>&1 || error "Cannot reach Kubernetes cluster"

# -----------------------------------------------------------------------------
# 1. Metrics Server
# -----------------------------------------------------------------------------
info "Adding metrics-server Helm repo..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update

info "Installing metrics-server v${METRICS_SERVER_VERSION}..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version "${METRICS_SERVER_VERSION}" \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP" \
  --wait --timeout=3m

info "Verifying metrics-server..."
sleep 15
kubectl top nodes >/dev/null 2>&1 \
  && info "✓ kubectl top nodes — OK" \
  || warn "metrics not yet available; wait ~30s and retry 'kubectl top nodes'"

# -----------------------------------------------------------------------------
# 2. Namespace
# -----------------------------------------------------------------------------
info "Creating monitoring namespace..."
kubectl create namespace ${MONITORING_NS} --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace ${MONITORING_NS} \
  app.kubernetes.io/part-of=cloudlab \
  cloudlab/component=monitoring \
  --overwrite

# -----------------------------------------------------------------------------
# 3. kube-prometheus-stack
# -----------------------------------------------------------------------------
info "Adding prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

info "Installing kube-prometheus-stack v${KUBE_PROM_VERSION}..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace ${MONITORING_NS} \
  --version "${KUBE_PROM_VERSION}" \
  --values "$(dirname "$0")/../observability/prometheus-values.yaml" \
  --wait --timeout=15m

# -----------------------------------------------------------------------------
# 4. Apply CloudLab custom dashboards and rules
# -----------------------------------------------------------------------------
info "Applying CloudLab alerting rules..."
kubectl apply -f "$(dirname "$0")/../observability/alerting-rules.yaml"

info "Applying CloudLab Grafana dashboards ConfigMap..."
kubectl apply -f "$(dirname "$0")/../observability/grafana-dashboards.yaml"

# -----------------------------------------------------------------------------
# 5. Verify deployments
# -----------------------------------------------------------------------------
info "Waiting for Prometheus operator..."
kubectl rollout status deployment/kube-prometheus-stack-operator \
  -n ${MONITORING_NS} --timeout=5m

info "Waiting for Grafana..."
kubectl rollout status deployment/kube-prometheus-stack-grafana \
  -n ${MONITORING_NS} --timeout=5m

info "Checking Prometheus StatefulSet..."
kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n ${MONITORING_NS} --timeout=5m

# Check scrape targets health (via API if accessible)
POD=$(kubectl get pod -n ${MONITORING_NS} \
  -l "app.kubernetes.io/name=prometheus" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$POD" ]]; then
  UP=$(kubectl exec "$POD" -n ${MONITORING_NS} -c prometheus -- \
    wget -qO- 'http://localhost:9090/api/v1/query?query=up' 2>/dev/null \
    | grep -o '"value":\[.*,"1"\]' | wc -l || true)
  info "Prometheus scrape targets reporting UP: ${UP}"
fi

echo ""
info "✓ Monitoring stack installed"
echo ""
echo "  Access Grafana:"
echo "    kubectl port-forward -n ${MONITORING_NS} svc/kube-prometheus-stack-grafana 3000:80"
echo "    URL: http://localhost:3000  |  user: admin  |  pass: cloudlab-admin"
echo ""
echo "  Access Prometheus:"
echo "    kubectl port-forward -n ${MONITORING_NS} svc/kube-prometheus-stack-prometheus 9090:9090"
echo "    URL: http://localhost:9090"
echo ""
echo "  Access Alertmanager:"
echo "    kubectl port-forward -n ${MONITORING_NS} svc/kube-prometheus-stack-alertmanager 9093:9093"
