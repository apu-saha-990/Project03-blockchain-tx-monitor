# Kubernetes Deployment — TX Monitor
## Every command, start to finish.

---

## Local (minikube) vs Cloud

This README covers **minikube** (local testing).
For cloud (EKS / GKE / AKS) — steps 1 and 2 differ. Everything from step 3 onward is identical.

---

## Full Start — minikube

### 1. Start minikube
```bash
minikube start --driver=docker
```

### 2. Point your shell at minikube's Docker daemon
```bash
eval $(minikube docker-env)
```
> Every `docker build` command after this builds INSIDE minikube, not your local Docker.
> This is required — without it, minikube can't find the image.

### 3. Build the app image inside minikube
```bash
docker build -t txmonitor:latest .
```

### 4. Return your shell to local Docker
```bash
eval $(minikube docker-env --unset)
```

### 5. Create namespace
```bash
kubectl apply -f k8s/namespace.yaml
```

### 6. Apply ConfigMap
```bash
kubectl apply -f k8s/configmap.yaml
```

### 7. Create secrets (never commit real values)
```bash
kubectl create secret generic txmonitor-secrets \
  --from-literal=ALCHEMY_WS_URL="$(grep ALCHEMY_WS_URL .env | cut -d= -f2)" \
  --from-literal=COINMARKETCAP_API_KEY="$(grep COINMARKETCAP_API_KEY .env | cut -d= -f2)" \
  -n txmonitor
```
> This pulls values directly from your `.env` file. No manual copy-paste of keys.

### 8. Deploy all components
```bash
kubectl apply -f k8s/timescaledb.yaml
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml
kubectl apply -f k8s/txmonitor.yaml
```

### 9. Verify pods are running
```bash
kubectl get pods -n txmonitor
```
> Wait until all pods show `Running`. TimescaleDB takes ~20 seconds.

### 10. Apply database schema
```bash
kubectl exec -n txmonitor -i \
  $(kubectl get pod -n txmonitor -l app=timescaledb -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U monitor -d txmonitor < src/storage/schema.sql
```
> Must be done once after TimescaleDB pod is Running and healthy.

### 11. Access services (port-forward)
```bash
# Grafana — http://localhost:3001
kubectl port-forward svc/grafana 3001:3000 -n txmonitor

# Prometheus — http://localhost:9090
kubectl port-forward svc/prometheus 9090:9090 -n txmonitor
```
> Grafana runs on 3001 locally to avoid conflict with Docker Compose on 3000.
> Each port-forward command blocks the terminal. Run in separate tabs.

---

## Verify Everything Works

```bash
# All pods running
kubectl get pods -n txmonitor

# All services exposed
kubectl get services -n txmonitor

# App logs
kubectl logs -n txmonitor -l app=txmonitor --tail=50

# TimescaleDB logs
kubectl logs -n txmonitor -l app=timescaledb --tail=20
```

---

## Tear Down

```bash
kubectl delete namespace txmonitor
```
> Deletes everything — pods, services, configmaps, secrets, volumes.

```bash
minikube stop
```

---

## Full Stop and Clean Restart (if something is broken)

```bash
# Delete namespace and everything in it
kubectl delete namespace txmonitor

# Stop minikube
minikube stop

# Start fresh
minikube start --driver=docker
eval $(minikube docker-env)
docker build -t txmonitor:latest .
eval $(minikube docker-env --unset)

# Redeploy from step 5
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl create secret generic txmonitor-secrets \
  --from-literal=ALCHEMY_WS_URL="$(grep ALCHEMY_WS_URL .env | cut -d= -f2)" \
  --from-literal=COINMARKETCAP_API_KEY="$(grep COINMARKETCAP_API_KEY .env | cut -d= -f2)" \
  -n txmonitor
kubectl apply -f k8s/timescaledb.yaml
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml
kubectl apply -f k8s/txmonitor.yaml
```

---

## Common Errors

**ImagePullBackOff or ErrImageNeverPull**
> You built the image in local Docker, not minikube's Docker.
> Fix: `eval $(minikube docker-env)` then `docker build -t txmonitor:latest .` again.
> `txmonitor.yaml` must have `imagePullPolicy: Never`.

**TimescaleDB pod not ready**
> Wait longer. It takes 20-30 seconds to initialise. Run `kubectl get pods -n txmonitor -w` to watch.

**Schema apply fails — connection refused**
> TimescaleDB pod isn't ready yet. Wait for `Running` status then retry step 10.

**Secret already exists**
> `kubectl delete secret txmonitor-secrets -n txmonitor` then recreate.

**Port-forward drops**
> Normal — port-forward is not persistent. Just re-run the command.

---

## Notes

- `txmonitor.yaml` has `imagePullPolicy: Never` — required for local minikube builds
- Grafana login: `admin / admin`
- Prometheus URL inside cluster: `http://txmonitor-prometheus:9090`
- TimescaleDB DSN inside cluster: `postgresql://monitor:monitor@timescaledb:5432/txmonitor`
