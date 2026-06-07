#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — K3s Teardown
# WARNING: Destroys the entire K3s cluster and all data.
# Use only for dev resets.
#
# Usage:
#   sudo ./infra/scripts/teardown-k3s.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

echo -e "${RED}${BOLD}WARNING: This will destroy the K3s cluster and all lab data.${NC}"
read -rp "Type 'destroy' to confirm: " confirm
[[ "$confirm" == "destroy" ]] || { echo "Aborted."; exit 0; }

echo "Stopping K3s..."
systemctl stop k3s 2>/dev/null || true

echo "Running K3s uninstall script..."
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || true

echo "Cleaning up CloudLab data..."
rm -rf /var/lib/cloudlab/registry

echo "Removing kubeconfig..."
CLOUDLAB_USER="${SUDO_USER:-$USER}"
rm -f "/home/${CLOUDLAB_USER}/.kube/config"

echo -e "${RED}K3s cluster destroyed.${NC}"
echo "To reinstall: sudo ./infra/scripts/bootstrap-k3s.sh"
