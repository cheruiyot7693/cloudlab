
# ── Kubernetes / K3s targets ──────────────────────────────────────────────────
k3s-install:
	sudo infra/scripts/bootstrap-k3s.sh

k3s-verify:
	infra/scripts/verify-cluster.sh

k3s-destroy:
	sudo infra/scripts/teardown-k3s.sh

k8s-apply:
	kubectl apply -f infra/k8s/namespaces.yaml
	kubectl apply -f infra/k8s/rbac.yaml
	kubectl apply -f infra/k8s/resource-quotas.yaml
	kubectl apply -f infra/k8s/local-registry.yaml

prometheus-install:
	infra/scripts/install-prometheus.sh

cluster-status:
	@echo "── Nodes ──────────────────────────────────────────────────"
	kubectl get nodes -o wide
	@echo ""
	@echo "── CloudLab Pods ──────────────────────────────────────────"
	kubectl get pods -n cloudlab-system
	kubectl get pods -n cloudlab-monitor
	@echo ""
	@echo "── Resource Usage ─────────────────────────────────────────"
	kubectl top nodes 2>/dev/null || echo "(metrics-server not ready)"

apply-manifests:
	infra/scripts/apply-manifests.sh

ns-list:
	python3 infra/scripts/namespace_provisioner.py --list

ns-create:
	@read -p "User ID: " uid; read -p "Lab ID: " lid; \
	python3 infra/scripts/namespace_provisioner.py --create --user $$uid --lab $$lid

ns-delete:
	@read -p "Namespace name: " ns; \
	python3 infra/scripts/namespace_provisioner.py --delete --namespace $$ns
