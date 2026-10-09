cat > scripts/deploy.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
ENV_NAME="${1:?usage: deploy.sh <dev|prod>}"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "== Namespace + RBAC =="
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/rbac.yaml

echo "== Sync backend secret =="
./scripts/sync-secrets.sh "$ENV_NAME"

echo "== App manifests =="
kubectl apply -f k8s/backend/configmap.yaml -f k8s/backend/deployment.yaml -f k8s/backend/service.yaml -f k8s/frontend/ -f k8s/ingress.yaml
kubectl -n zuri-market rollout status deployment/backend --timeout=120s
kubectl -n zuri-market rollout status deployment/frontend --timeout=120s

echo "== Monitoring namespace + Grafana secret =="
kubectl get namespace monitoring >/dev/null 2>&1 || kubectl create namespace monitoring

if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  GRAFANA_PW="$(aws secretsmanager get-secret-value --secret-id "zuri/${ENV_NAME}/grafana" \
    --query SecretString --output text --region eu-west-1 2>/dev/null || true)"
  if [ -z "$GRAFANA_PW" ]; then
    GRAFANA_PW="$(openssl rand -base64 18)"
    aws secretsmanager put-secret-value --secret-id "zuri/${ENV_NAME}/grafana" \
      --secret-string "$GRAFANA_PW" --region eu-west-1
  fi
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$GRAFANA_PW"
fi

echo "== Prometheus + Grafana via Helm =="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring/values.yaml

echo "== ServiceMonitor =="
kubectl apply -f k8s/backend/servicemonitor.yaml

echo "Deploy complete."
EOF
chmod +x scripts/deploy.sh