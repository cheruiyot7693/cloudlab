#!/usr/bin/env python3
"""
Validate all Containerlab topology YAML files in lab-catalog/topologies/.
Run by CI on every PR that touches lab-catalog/.

Exit 0 = all valid
Exit 1 = one or more invalid
"""

import sys
import os
import yaml
from pathlib import Path

REQUIRED_TOP_LEVEL_KEYS = {"name", "topology"}
REQUIRED_TOPOLOGY_KEYS = {"nodes"}
VALID_KINDS = {
    "linux", "frr", "vyos", "ceos", "vr-csr", "vr-sros",
    "vr-vmx", "vr-xrv9k", "bridge", "ovs-bridge", "host",
}

CATALOG_DIR = Path(__file__).parent.parent / "topologies"


def validate_file(path: Path) -> list[str]:
    errors = []

    try:
        with open(path) as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        return [f"YAML parse error: {e}"]

    if not isinstance(data, dict):
        return ["Root must be a YAML mapping"]

    missing_top = REQUIRED_TOP_LEVEL_KEYS - data.keys()
    if missing_top:
        errors.append(f"Missing required top-level keys: {missing_top}")

    topology = data.get("topology", {})
    if not isinstance(topology, dict):
        errors.append("'topology' must be a mapping")
        return errors

    missing_topo = REQUIRED_TOPOLOGY_KEYS - topology.keys()
    if missing_topo:
        errors.append(f"Missing required topology keys: {missing_topo}")

    nodes = topology.get("nodes", {})
    if not isinstance(nodes, dict) or len(nodes) == 0:
        errors.append("'topology.nodes' must be a non-empty mapping")

    # Validate metadata file exists alongside topology
    meta_path = path.with_suffix(".meta.json")
    if not meta_path.exists():
        errors.append(f"Missing metadata file: {meta_path.name}")

    return errors


def main() -> int:
    if not CATALOG_DIR.exists():
        print(f"Topology directory not found: {CATALOG_DIR}")
        return 0  # nothing to validate yet

    topology_files = list(CATALOG_DIR.glob("**/*.clab.yml"))

    if not topology_files:
        print("No topology files found — skipping validation.")
        return 0

    failed = 0
    for path in sorted(topology_files):
        errors = validate_file(path)
        rel = path.relative_to(CATALOG_DIR.parent.parent)
        if errors:
            print(f"❌ {rel}")
            for e in errors:
                print(f"   • {e}")
            failed += 1
        else:
            print(f"✅ {rel}")

    print(f"\n{len(topology_files)} topologies checked. {failed} failed.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
