"""
Tests for the namespace provisioner.
Uses unittest.mock to avoid needing a real K8s cluster.
"""

from unittest.mock import MagicMock, patch, call
import pytest

from infra.scripts.namespace_provisioner import NamespaceProvisioner


@pytest.fixture
def provisioner():
    """Return a provisioner with mocked K8s clients."""
    with patch("infra.scripts.namespace_provisioner.config"):
        p = NamespaceProvisioner(in_cluster=False)
        p.core = MagicMock()
        p.networking = MagicMock()
        p.rbac = MagicMock()
        return p


class TestNamespaceName:
    def test_basic(self):
        name = NamespaceProvisioner.namespace_name("user123", "lab456")
        assert name == "lab-user123-lab456"

    def test_truncates_long_ids(self):
        name = NamespaceProvisioner.namespace_name("a" * 20, "b" * 20)
        assert len(name) <= 63
        assert name.startswith("lab-")

    def test_replaces_underscores(self):
        name = NamespaceProvisioner.namespace_name("user_one", "lab_two")
        assert "_" not in name

    def test_lowercase(self):
        name = NamespaceProvisioner.namespace_name("USER123", "LAB456")
        assert name == name.lower()


class TestCreate:
    def test_creates_namespace(self, provisioner):
        # Namespace does not exist yet
        from kubernetes.client.exceptions import ApiException
        provisioner.core.read_namespace.side_effect = ApiException(status=404)

        result = provisioner.create("user01", "lab01", "ospf-single-area")

        assert result.namespace == "lab-user01-lab01"
        provisioner.core.create_namespace.assert_called_once()

    def test_applies_resource_quota(self, provisioner):
        from kubernetes.client.exceptions import ApiException
        provisioner.core.read_namespace.side_effect = ApiException(status=404)

        provisioner.create("user01", "lab01")

        provisioner.core.create_namespaced_resource_quota.assert_called_once()

    def test_applies_limit_range(self, provisioner):
        from kubernetes.client.exceptions import ApiException
        provisioner.core.read_namespace.side_effect = ApiException(status=404)

        provisioner.create("user01", "lab01")

        provisioner.core.create_namespaced_limit_range.assert_called_once()

    def test_applies_network_policy(self, provisioner):
        from kubernetes.client.exceptions import ApiException
        provisioner.core.read_namespace.side_effect = ApiException(status=404)

        provisioner.create("user01", "lab01")

        provisioner.networking.create_namespaced_network_policy.assert_called_once()

    def test_creates_service_account(self, provisioner):
        from kubernetes.client.exceptions import ApiException
        provisioner.core.read_namespace.side_effect = ApiException(status=404)

        provisioner.create("user01", "lab01")

        provisioner.core.create_namespaced_service_account.assert_called_once()

    def test_skips_if_namespace_exists(self, provisioner):
        # Namespace already exists
        provisioner.core.read_namespace.return_value = MagicMock()

        result = provisioner.create("user01", "lab01")

        provisioner.core.create_namespace.assert_not_called()
        assert result.namespace == "lab-user01-lab01"


class TestDelete:
    def test_deletes_existing_namespace(self, provisioner):
        provisioner.core.read_namespace.return_value = MagicMock()

        provisioner.delete("lab-user01-lab01")

        provisioner.core.delete_namespace.assert_called_once_with(
            "lab-user01-lab01",
            body=pytest.approx(MagicMock(), abs=1),
        )

    def test_skips_missing_namespace(self, provisioner):
        from kubernetes.client.exceptions import ApiException
        provisioner.core.read_namespace.side_effect = ApiException(status=404)

        # Should not raise
        provisioner.delete("lab-nonexistent")
        provisioner.core.delete_namespace.assert_not_called()


class TestList:
    def test_returns_lab_namespaces(self, provisioner):
        from datetime import datetime, timezone

        mock_ns = MagicMock()
        mock_ns.metadata.name = "lab-user01-lab01"
        mock_ns.metadata.labels = {
            "cloudlab/user-id": "user01",
            "cloudlab/lab-id": "lab01",
            "cloudlab/topology": "ospf-single-area",
        }
        mock_ns.status.phase = "Active"
        mock_ns.metadata.creation_timestamp = datetime(2026, 1, 1, tzinfo=timezone.utc)

        provisioner.core.list_namespace.return_value = MagicMock(items=[mock_ns])

        result = provisioner.list_lab_namespaces()

        assert len(result) == 1
        assert result[0]["name"] == "lab-user01-lab01"
        assert result[0]["user_id"] == "user01"
