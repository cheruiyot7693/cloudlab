"""
CloudLab Platform — Lab Namespace Provisioner
=============================================
Handles creation and teardown of per-lab Kubernetes namespaces.

Each running lab gets its own isolated namespace:
    lab-<user_id_short>-<lab_id_short>

This module is called by the lab lifecycle API (Phase 1).
For Phase 0.3 it is a standalone utility — can be tested directly.

Usage (standalone test):
    python3 -m infra.scripts.namespace_provisioner --create --user abc123 --lab xyz789
    python3 -m infra.scripts.namespace_provisioner --delete --namespace lab-abc123-xyz789
"""

from __future__ import annotations

import argparse
import logging
import sys
from dataclasses import dataclass

from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

logger = logging.getLogger(__name__)


# ── Constants ─────────────────────────────────────────────────────────────────
LABS_POOL_NAMESPACE = "cloudlab-labs"
SYSTEM_NAMESPACE = "cloudlab-system"

# Resource limits per lab namespace (tuned for 8GB dev machine)
DEFAULT_QUOTA = {
    "requests.cpu": "500m",
    "requests.memory": "512Mi",
    "limits.cpu": "2",
    "limits.memory": "1Gi",
    "count/pods": "10",
}

DEFAULT_LIMIT_RANGE = {
    "default_cpu": "500m",
    "default_memory": "256Mi",
    "default_request_cpu": "100m",
    "default_request_memory": "128Mi",
    "max_cpu": "2",
    "max_memory": "1Gi",
}


# ── Data classes ──────────────────────────────────────────────────────────────
@dataclass
class LabNamespace:
    name: str
    user_id: str
    lab_id: str
    namespace: str


# ── Provisioner ───────────────────────────────────────────────────────────────
class NamespaceProvisioner:
    """Manages Kubernetes namespace lifecycle for CloudLab labs."""

    def __init__(self, in_cluster: bool = False) -> None:
        """
        Args:
            in_cluster: True when running inside K8s (backend pod).
                        False when running locally (uses ~/.kube/config).
        """
        if in_cluster:
            config.load_incluster_config()
        else:
            config.load_kube_config()

        self.core = client.CoreV1Api()
        self.networking = client.NetworkingV1Api()
        self.rbac = client.RbacAuthorizationV1Api()

    # ── Helpers ───────────────────────────────────────────────────────────────
    @staticmethod
    def namespace_name(user_id: str, lab_id: str) -> str:
        """
        Generate a deterministic, DNS-safe namespace name.
        Truncates IDs to keep name under 63 chars (K8s label limit).

        Example: lab-abc12345-xyz78901
        """
        u = user_id[:8].lower().replace("_", "-")
        l = lab_id[:8].lower().replace("_", "-")
        return f"lab-{u}-{l}"

    def _namespace_exists(self, name: str) -> bool:
        try:
            self.core.read_namespace(name)
            return True
        except ApiException as e:
            if e.status == 404:
                return False
            raise

    # ── Create ────────────────────────────────────────────────────────────────
    def create(
        self,
        user_id: str,
        lab_id: str,
        topology_name: str = "unknown",
        extra_labels: dict | None = None,
    ) -> LabNamespace:
        """
        Create an isolated namespace for a lab session.

        Steps:
          1. Create namespace with CloudLab labels
          2. Apply ResourceQuota (CPU/memory cap)
          3. Apply LimitRange (default per-container limits)
          4. Apply NetworkPolicy (isolate from other labs)
          5. Create ServiceAccount for Containerlab operator

        Returns:
            LabNamespace with the created namespace name.
        """
        ns_name = self.namespace_name(user_id, lab_id)

        if self._namespace_exists(ns_name):
            logger.info("Namespace already exists: %s", ns_name)
            return LabNamespace(
                name=ns_name,
                user_id=user_id,
                lab_id=lab_id,
                namespace=ns_name,
            )

        labels = {
            "app.kubernetes.io/part-of": "cloudlab",
            "cloudlab/namespace-type": "lab",
            "cloudlab/user-id": user_id[:63],
            "cloudlab/lab-id": lab_id[:63],
            "cloudlab/topology": topology_name[:63],
        }
        if extra_labels:
            labels.update(extra_labels)

        # 1. Create namespace
        ns = client.V1Namespace(
            metadata=client.V1ObjectMeta(name=ns_name, labels=labels)
        )
        self.core.create_namespace(ns)
        logger.info("Created namespace: %s", ns_name)

        # 2. ResourceQuota
        self._apply_resource_quota(ns_name)

        # 3. LimitRange
        self._apply_limit_range(ns_name)

        # 4. NetworkPolicy — deny cross-lab traffic
        self._apply_network_policy(ns_name)

        # 5. ServiceAccount for Containerlab
        self._apply_service_account(ns_name)

        logger.info("Namespace %s fully provisioned", ns_name)
        return LabNamespace(
            name=ns_name,
            user_id=user_id,
            lab_id=lab_id,
            namespace=ns_name,
        )

    def _apply_resource_quota(self, ns_name: str) -> None:
        quota = client.V1ResourceQuota(
            metadata=client.V1ObjectMeta(name="lab-quota", namespace=ns_name),
            spec=client.V1ResourceQuotaSpec(hard=DEFAULT_QUOTA),
        )
        self.core.create_namespaced_resource_quota(ns_name, quota)
        logger.debug("ResourceQuota applied to %s", ns_name)

    def _apply_limit_range(self, ns_name: str) -> None:
        lr = client.V1LimitRange(
            metadata=client.V1ObjectMeta(name="lab-limits", namespace=ns_name),
            spec=client.V1LimitRangeSpec(
                limits=[
                    client.V1LimitRangeItem(
                        type="Container",
                        default={
                            "cpu": DEFAULT_LIMIT_RANGE["default_cpu"],
                            "memory": DEFAULT_LIMIT_RANGE["default_memory"],
                        },
                        default_request={
                            "cpu": DEFAULT_LIMIT_RANGE["default_request_cpu"],
                            "memory": DEFAULT_LIMIT_RANGE["default_request_memory"],
                        },
                        max={
                            "cpu": DEFAULT_LIMIT_RANGE["max_cpu"],
                            "memory": DEFAULT_LIMIT_RANGE["max_memory"],
                        },
                    )
                ]
            ),
        )
        self.core.create_namespaced_limit_range(ns_name, lr)
        logger.debug("LimitRange applied to %s", ns_name)

    def _apply_network_policy(self, ns_name: str) -> None:
        """Deny all ingress from other lab namespaces."""
        policy = client.V1NetworkPolicy(
            metadata=client.V1ObjectMeta(name="deny-cross-lab", namespace=ns_name),
            spec=client.V1NetworkPolicySpec(
                pod_selector=client.V1LabelSelector(),
                policy_types=["Ingress", "Egress"],
                ingress=[
                    # Only allow intra-namespace traffic (nodes talking to each other)
                    client.V1NetworkPolicyIngressRule(
                        _from=[
                            client.V1NetworkPolicyPeer(
                                namespace_selector=client.V1LabelSelector(
                                    match_labels={"cloudlab/lab-id": ns_name.split("-")[-1]}
                                )
                            )
                        ]
                    )
                ],
                egress=[
                    # Allow DNS
                    client.V1NetworkPolicyEgressRule(
                        ports=[
                            client.V1NetworkPolicyPort(port=53, protocol="UDP"),
                            client.V1NetworkPolicyPort(port=53, protocol="TCP"),
                        ]
                    ),
                    # Allow internet (for lab traffic simulation)
                    client.V1NetworkPolicyEgressRule(
                        to=[
                            client.V1NetworkPolicyPeer(
                                ip_block=client.V1IPBlock(
                                    cidr="0.0.0.0/0",
                                    _except=["10.42.0.0/16", "10.43.0.0/16"],
                                )
                            )
                        ]
                    ),
                ],
            ),
        )
        self.networking.create_namespaced_network_policy(ns_name, policy)
        logger.debug("NetworkPolicy applied to %s", ns_name)

    def _apply_service_account(self, ns_name: str) -> None:
        sa = client.V1ServiceAccount(
            metadata=client.V1ObjectMeta(name="lab-runner", namespace=ns_name)
        )
        self.core.create_namespaced_service_account(ns_name, sa)
        logger.debug("ServiceAccount lab-runner created in %s", ns_name)

    # ── Delete ────────────────────────────────────────────────────────────────
    def delete(self, ns_name: str) -> None:
        """
        Delete a lab namespace and all its resources.
        K8s cascades deletion to all pods, services, PVCs inside.
        """
        if not self._namespace_exists(ns_name):
            logger.warning("Namespace not found (already deleted?): %s", ns_name)
            return

        self.core.delete_namespace(
            ns_name,
            body=client.V1DeleteOptions(grace_period_seconds=30),
        )
        logger.info("Namespace deleted: %s", ns_name)

    # ── List ──────────────────────────────────────────────────────────────────
    def list_lab_namespaces(self) -> list[dict]:
        """Return all active lab namespaces with their labels."""
        ns_list = self.core.list_namespace(
            label_selector="cloudlab/namespace-type=lab"
        )
        return [
            {
                "name": ns.metadata.name,
                "user_id": ns.metadata.labels.get("cloudlab/user-id"),
                "lab_id": ns.metadata.labels.get("cloudlab/lab-id"),
                "topology": ns.metadata.labels.get("cloudlab/topology"),
                "phase": ns.status.phase,
                "created": ns.metadata.creation_timestamp.isoformat()
                if ns.metadata.creation_timestamp
                else None,
            }
            for ns in ns_list.items
        ]


# ── CLI for manual testing ────────────────────────────────────────────────────
def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    parser = argparse.ArgumentParser(description="CloudLab namespace provisioner")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--create", action="store_true", help="Create a lab namespace")
    group.add_argument("--delete", action="store_true", help="Delete a lab namespace")
    group.add_argument("--list", action="store_true", help="List all lab namespaces")

    parser.add_argument("--user", help="User ID (required for --create)")
    parser.add_argument("--lab", help="Lab ID (required for --create)")
    parser.add_argument("--namespace", help="Namespace name (required for --delete)")
    parser.add_argument("--topology", default="unknown", help="Topology name label")

    args = parser.parse_args()
    provisioner = NamespaceProvisioner(in_cluster=False)

    if args.create:
        if not args.user or not args.lab:
            parser.error("--create requires --user and --lab")
        result = provisioner.create(args.user, args.lab, args.topology)
        print(f"Created: {result.namespace}")

    elif args.delete:
        if not args.namespace:
            parser.error("--delete requires --namespace")
        provisioner.delete(args.namespace)
        print(f"Deleted: {args.namespace}")

    elif args.list:
        namespaces = provisioner.list_lab_namespaces()
        if not namespaces:
            print("No active lab namespaces.")
        for ns in namespaces:
            print(f"  {ns['name']}  user={ns['user_id']}  lab={ns['lab_id']}  status={ns['phase']}")


if __name__ == "__main__":
    main()
