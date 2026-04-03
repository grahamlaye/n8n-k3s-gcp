# n8n GKE Deployment Runbook

## Prerequisites
- `terraform` / `tf` alias
- `kubectl` / `k` alias
- `helm`
- `gcloud` authenticated to `n8n-demo-lab`

## 1. Deploy infrastructure
```powershell
tf init
tf plan -out=tfplan
tf apply tfplan
```

## 3. Configure kubectl
```powershell
gcloud container clusters get-credentials n8n-cluster --zone=europe-west2-a
k get nodes
```

## 4. Create n8n namespace
```powershell
k apply -f kubernetes\namespace.yaml
```

## 5. K8s secrets
All K8s secrets are now managed by Terraform — sourced from GCP Secret Manager.
They are created automatically during `tf apply`. No manual `kubectl create secret` needed.

To rotate a secret: update the value in Secret Manager, then run `tf apply`.

## 6. Enable pgvector (one-time, post-apply)
```powershell
gcloud sql connect n8n-postgres --user=postgres --database=ragdb --project=n8n-demo-lab
```
Then in the psql prompt:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
\q
```

## 7. Install Traefik ingress controller
```powershell
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik --namespace traefik --create-namespace
```

### Verify Traefik
```powershell
k get svc -n traefik  # Wait for EXTERNAL-IP to be assigned
```
Traefik external IP: `34.105.214.176` (ports 80 and 443)

## 8. Install cert-manager (TLS certificates via Let's Encrypt)
```powershell
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager `
  --namespace cert-manager `
  --create-namespace `
  --set crds.enabled=true
```

### Verify cert-manager
```powershell
k get pods -n cert-manager
helm list -n cert-manager
```
Note: If Helm shows `failed` status due to startup check timeout but all pods are Running, fix with:
```powershell
helm upgrade cert-manager jetstack/cert-manager `
  --namespace cert-manager `
  --set crds.enabled=true
```

## 9. Deploy n8n and Affine
```powershell
k apply -f kubernetes\
k apply -f kubernetes\affine\
```

## 10. DNS — point these A records at 34.105.214.176
| Hostname | Service |
|----------|---------|
| n8n.gbone.one | n8n |
| affine.gbone.one | Affine wiki |

## 11. Verify deployments
```powershell
k get all -n n8n
k get all -n affine
k logs -n n8n deployment/n8n
k logs -n affine deployment/affine
```

## 12. Deploy Prometheus and Grafana

### Create monitoring namespace and Grafana secret
```powershell
kubectl create namespace monitoring

kubectl create secret generic grafana-admin-secret `
  --namespace=monitoring `
  --from-literal=admin-user=admin `
  --from-literal=admin-password="<your-grafana-password-from-bitwarden>"
```

### Install kube-prometheus-stack via Helm
```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values kubernetes\monitoring\prometheus-stack-values.yaml
```

### Apply certs and ingress
```powershell
k apply -f kubernetes\monitoring\
```

### Add to hosts file (C:\Windows\System32\drivers\etc\hosts)
```
34.105.214.176  grafana.local
34.105.214.176  prometheus.local
```

### Verify
```powershell
k get pods -n monitoring
k get ingress -n monitoring
```

Access at:
- https://grafana.local
- https://prometheus.local

## Tear down
```powershell
k delete -f kubernetes\
helm uninstall traefik -n traefik
helm uninstall cert-manager -n cert-manager
tf destroy
```
