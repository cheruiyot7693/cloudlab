#!/usr/bin/env bash
# =============================================================================
# CloudLab Platform — Test First Lab (Local Containerlab)
# Tests the OSPF single-area topology directly with Containerlab
# before the K8s operator integration is ready.
#
# Requirements:
#   - Containerlab installed: bash -c "$(curl -sL https://get.containerlab.dev)"
#   - Docker running
#
# Usage:
#   chmod +x infra/scripts/test-first-lab.sh
#   sudo ./infra/scripts/test-first-lab.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${BOLD}══ $* ══${NC}"; }

TOPO="lab-catalog/topologies/ospf-single-area.clab.yml"

# ── Check containerlab ────────────────────────────────────────────────────────
section "Prerequisites"

if ! command -v containerlab &>/dev/null; then
  warn "Containerlab not installed. Installing..."
  bash -c "$(curl -sL https://get.containerlab.dev)"
fi
success "Containerlab: $(containerlab version | grep 'version' | awk '{print $2}')"

command -v docker &>/dev/null || { echo "Docker not found"; exit 1; }
success "Docker available"

# ── Pull FRR image ────────────────────────────────────────────────────────────
section "Pulling FRR Image"
info "Pulling frrouting/frr:v9.1.0 (free, no license needed)..."
docker pull frrouting/frr:v9.1.0
success "FRR image ready"

# ── Deploy lab ────────────────────────────────────────────────────────────────
section "Deploying OSPF Single-Area Lab"
info "Topology: $TOPO"
info "Nodes: R1, R2, R3 (FRR), PC1 (Alpine)"

START=$(date +%s)
containerlab deploy --topo "$TOPO" --reconfigure
END=$(date +%s)
ELAPSED=$((END - START))

success "Lab deployed in ${ELAPSED}s"

# ── Wait for OSPF to converge ─────────────────────────────────────────────────
section "Waiting for OSPF Convergence"
info "Giving OSPF 30s to establish adjacencies..."
sleep 30

# ── Verify OSPF neighbors ─────────────────────────────────────────────────────
section "Verifying OSPF Neighbors on R1"

echo ""
info "R1 OSPF neighbors (expect: R2 and R3 in FULL state):"
docker exec clab-ospf-single-area-R1 vtysh -c "show ip ospf neighbor" 2>/dev/null || \
  warn "vtysh not ready yet — try manually: docker exec -it clab-ospf-single-area-R1 vtysh"

echo ""
info "R1 OSPF routes (expect routes to 2.2.2.2 and 3.3.3.3):"
docker exec clab-ospf-single-area-R1 vtysh -c "show ip route ospf" 2>/dev/null || true

echo ""
info "Ping R3 loopback from R1 (expect: success):"
docker exec clab-ospf-single-area-R1 ping -c 3 3.3.3.3 2>/dev/null || \
  warn "Ping failed — OSPF may still be converging"

# ── Print access info ─────────────────────────────────────────────────────────
section "Lab Access"
echo ""
echo -e "${BOLD}Connect to routers:${NC}"
echo "  docker exec -it clab-ospf-single-area-R1 vtysh"
echo "  docker exec -it clab-ospf-single-area-R2 vtysh"
echo "  docker exec -it clab-ospf-single-area-R3 vtysh"
echo ""
echo -e "${BOLD}Useful OSPF commands (inside vtysh):${NC}"
echo "  show ip ospf neighbor"
echo "  show ip ospf interface"
echo "  show ip route ospf"
echo "  show ip ospf database"
echo ""
echo -e "${BOLD}Destroy lab when done:${NC}"
echo "  sudo containerlab destroy --topo $TOPO"
echo ""

success "OSPF Single-Area lab is running!"
