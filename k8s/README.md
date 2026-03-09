# Kubernetes Deployment — TX Monitor

## Prerequisites
- Kubernetes cluster (local: minikube / k3s, cloud: EKS / GKE / AKS)
- kubectl configured
- Secrets populated

## Deploy

### 1. Create namespace
```bash
kubectl apply -f namespace.yaml
```

### 2. Create secrets (never commit real values)
```bash
kubectl create secret generic txmonitor-secrets \
  --from-literal=ALCHEMY_WS_URL='wss://eth-mainnet.g.alchemy.com/v2/YOUR_KEY' \
  --from-literal=COINMARKETCAP_API_KEY='YOUR_KEY' \
  -n txmonitor
```

### 3. Deploy all components
```bash
kubectl apply -f configmap.yaml
kubectl apply -f timescaledb.yaml
kubectl apply -f prometheus.yaml
kubectl apply -f grafana.yaml
kubectl apply -f txmonitor.yaml
```

### 4. Verify
```bash
kubectl get pods -n txmonitor
kubectl get services -n txmonitor
```

### 5. Access services (local port-forward)
```bash
# Grafana
kubectl port-forward svc/grafana 3000:3000 -n txmonitor

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n txmonitor
```

## Tear down
```bash
kubectl delete namespace txmonitor
```
