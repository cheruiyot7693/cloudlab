#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — K3s Bootstrap Script
# Target: Local dev machine (8GB RAM, Kali/Debian Linux)
#
# What this script does:
#   1. Pre-flight checks (RAM, CPU, OS, required tools)
#   2. Installs K3s with a lean config (no Traefik, no ServiceLB — saves ~200MB RAM)
#   3. Configures kubeconfig for the current user
#   4. Creates CloudLab namespaces and RBAC
#   5. Verifies the cluster is healthy
#
# Usage:
#   chmod +x infra/scripts/bootstrap-k3s.sh
#   sudo ./infra/scripts/bootstrap-k3s.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}══ $* ══${NC}"; }

# ── Config ────────────────────────────────────────────────────────────────────
K3S_VERSION="v1.29.4+k3s1"
CLOUDLAB_USER="${SUDO_USER:-$USER}"
KUBECONFIG_DIR="/home/${CLOUDLAB_USER}/.kube"
KUBECONFIG_PATH="${KUBECONFIG_DIR}/config"

# Namespaces
NAMESPACES=(
  "cloudlab-system"    # platform services: backend, frontend, keycloak
  "cloudlab-labs"      # user lab namespaces created dynamically
  "cloudlab-monitor"   # prometheus, grafana, loki
)

# ── Pre-flight ────────────────────────────────────────────────────────────────
section "Pre-flight Checks"

# Must run as root
[[ $EUID -eq 0 ]] || error "Run with sudo: sudo $0"

# OS check
if ! grep -qiE "debian|kali|ubuntu" /etc/os-release 2>/dev/null; then
  warn "Untested OS. Proceed with caution."
fi

# RAM check — warn if under 6GB free
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
if [[ $TOTAL_RAM_GB -lt 6 ]]; then
  warn "Only ${TOTAL_RAM_GB}GB RAM detected. Minimum recommended is 6GB."
  warn "K3s will run but lab capacity will be very limited."
else
  success "RAM: ${TOTAL_RAM_GB}GB detected"
fi

# CPU check
CPU_CORES=$(nproc)
if [[ $CPU_CORES -lt 2 ]]; then
  error "Minimum 2 CPU cores required. Detected: ${CPU_CORES}"
fi
success "CPU: ${CPU_CORES} cores detected"

# Check required tools
for cmd in curl iptables; do
  if ! command -v "$cmd" &>/dev/null; then
    error "Required tool not found: $cmd. Install with: sudo apt install $cmd"
  fi
done
success "Required tools present"

# Check if K3s already installed
if command -v k3s &>/dev/null; then
  warn "K3s is already installed ($(k3s --version | head -1))"
  read -rp "Reinstall? This will reset the cluster. [y/N]: " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    info "Skipping K3s install. Continuing with namespace setup..."
    SKIP_INSTALL=true
  else
    info "Uninstalling existing K3s..."
    /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
    SKIP_INSTALL=false
  fi
else
  SKIP_INSTALL=false
fi

# ── Install K3s ───────────────────────────────────────────────────────────────
section "Installing K3s ${K3S_VERSION}"

if [[ "${SKIP_INSTALL}" == "false" ]]; then
  info "Downloading and installing K3s..."
  info "Flags: --disable traefik --disable servicelb (saves ~200MB RAM on 8GB machine)"

  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    sh -s - server \
      --disable traefik \
      --disable servicelb \
      --write-kubeconfig-mode 644 \
      --kube-apiserver-arg="--request-timeout=300s" \
      --kubelet-arg="--max-pods=110" \
      --kubelet-arg="--eviction-hard=memory.available<200Mi" \
      --kubelet-arg="--system-reserved=cpu=200m,memory=512Mi" \
      --kubelet-arg="--kube-reserved=cpu=200m,memory=256Mi"

  success "K3s installed"

  # Wait for K3s to be ready
  info "Waiting for K3s API server to be ready..."
  timeout 120 bash -c 'until k3s kubectl get nodes &>/dev/null; do sleep 3; done'
  success "K3s API server is up"
fi

# ── Kubeconfig ────────────────────────────────────────────────────────────────
section "Configuring kubeconfig"

mkdir -p "${KUBECONFIG_DIR}"
cp /etc/rancher/k3s/k3s.yaml "${KUBECONFIG_PATH}"
# Replace 127.0.0.1 with localhost for clarity
sed -i 's/127\.0\.0\.1/localhost/g' "${KUBECONFIG_PATH}"
chown -R "${CLOUDLAB_USER}:${CLOUDLAB_USER}" "${KUBECONFIG_DIR}"
chmod 600 "${KUBECONFIG_PATH}"

success "kubeconfig written to ${KUBECONFIG_PATH}"
info "Add to your shell profile:"
echo ""
echo "  export KUBECONFIG=${KUBECONFIG_PATH}"
echo ""

# Export for remainder of this script
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ── Wait for node ready ───────────────────────────────────────────────────────
section "Waiting for Node Ready"

info "Waiting for the node to reach Ready state..."
timeout 180 bash -c 'until k3s kubectl get node | grep -q " Ready"; do sleep 5; done'
success "Node is Ready"
k3s kubectl get nodes -o wide

# ── Namespaces ────────────────────────────────────────────────────────────────
section "Creating CloudLab Namespaces"

for ns in "${NAMESPACES[@]}"; do
  if k3s kubectl get namespace "$ns" &>/dev/null; then
    info "Namespace already exists: $ns"
  else
    k3s kubectl create namespace "$ns"
    success "Created namespace: $ns"
  fi
done

# Label namespaces
k3s kubectl label namespace cloudlab-system  app.kubernetes.io/part-of=cloudlab --overwrite
k3s kubectl label namespace cloudlab-labs    app.kubernetes.io/part-of=cloudlab --overwrite
k3s kubectl label namespace cloudlab-monitor app.kubernetes.io/part-of=cloudlab --overwrite

# ── RBAC ─────────────────────────────────────────────────────────────────────
section "Applying RBAC"

k3s kubectl apply -f - <<'EOF'
---
# ServiceAccount for CloudLab backend to manage lab namespaces
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudlab-backend
  namespace: cloudlab-system
---
# ClusterRole: backend can manage pods, services, namespaces for labs
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudlab-lab-manager
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "services", "configmaps", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["clabs.nokia.com"]
    resources: ["containerlabs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Bind the role to the backend service account
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudlab-backend-lab-manager
subjects:
  - kind: ServiceAccount
    name: cloudlab-backend
    namespace: cloudlab-system
roleRef:
  kind: ClusterRole
  name: cloudlab-lab-manager
  apiGroup: rbac.authorization.k8s.io
EOF

success "RBAC applied"

# ── Resource Quotas (8GB RAM budget) ─────────────────────────────────────────
section "Applying Resource Quotas"

# cloudlab-labs: cap total lab resource consumption
k3s kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: lab-resource-quota
  namespace: cloudlab-labs
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "6"
    limits.memory: 5Gi
    count/pods: "50"
    persistentvolumeclaims: "20"
EOF

# cloudlab-system: platform services quota
k3s kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: system-resource-quota
  namespace: cloudlab-system
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "3"
    limits.memory: 3Gi
    count/pods: "20"
EOF

success "Resource quotas applied"

# ── LimitRange (default limits per pod) ──────────────────────────────────────
k3s kubectl apply -f - <<'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: cloudlab-labs
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "1Gi"
EOF

success "LimitRange applied to cloudlab-labs"

# ── Local image registry ──────────────────────────────────────────────────────
section "Deploying Local Image Registry"

k3s kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: local-registry
  namespace: cloudlab-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: local-registry
  template:
    metadata:
      labels:
        app: local-registry
    spec:
      containers:
        - name: registry
          image: registry:2
          ports:
            - containerPort: 5000
          env:
            - name: REGISTRY_STORAGE_DELETE_ENABLED
              value: "true"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: local-registry
  namespace: cloudlab-system
spec:
  selector:
    app: local-registry
  ports:
    - port: 5000
      targetPort: 5000
  type: ClusterIP
EOF

success "Local registry deployed"

# Configure K3s to trust the local registry
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/registries.yaml <<'EOF'
mirrors:
  "local-registry.cloudlab-system.svc.cluster.local:5000":
    endpoint:
      - "http://local-registry.cloudlab-system.svc.cluster.local:5000"
EOF

success "K3s registry mirror configured"

# ── Verification ──────────────────────────────────────────────────────────────
section "Cluster Verification"

echo ""
info "Nodes:"
k3s kubectl get nodes -o wide

echo ""
info "Namespaces:"
k3s kubectl get namespaces -l app.kubernetes.io/part-of=cloudlab

echo ""
info "Resource Quotas:"
k3s kubectl get resourcequota -A

echo ""
info "System pods:"
k3s kubectl get pods -n kube-system

echo ""
success "K3s bootstrap complete!"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Add to ~/.bashrc:  export KUBECONFIG=${KUBECONFIG_PATH}"
echo "  2. Reload shell:      source ~/.bashrc"
echo "  3. Verify:            kubectl get nodes"
echo "  4. Run Phase 0.3b:    infra/scripts/install-operators.sh"
echo ""
