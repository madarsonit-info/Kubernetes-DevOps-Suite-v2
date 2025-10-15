# Deployment Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Deployment Methods](#deployment-methods)
- [Azure Marketplace Deployment](#azure-marketplace-deployment)
- [Helm Chart Deployment](#helm-chart-deployment)
- [Porter Bundle Deployment](#porter-bundle-deployment)
- [Post-Deployment Steps](#post-deployment-steps)
- [Verification](#verification)

---

## Prerequisites

### Azure Resources
- **Azure Subscription** with Contributor or Owner role
- **Azure Kubernetes Service (AKS)** cluster
  - Kubernetes version 1.24 or higher
  - Minimum 3 nodes
  - Node size: Standard_D4s_v3 or larger (4 vCPUs, 16GB RAM)
  - Network plugin: Azure CNI or Kubenet
- **Azure Storage Account** (optional, for persistent storage)

### Local Tools (for manual deployment)
- `kubectl` version 1.24+
- `helm` version 3.8+
- `az` CLI version 2.40+
- `porter` (for Porter bundle deployment)

### Cluster Requirements
```bash
# Minimum cluster specifications
Nodes: 3
vCPUs per node: 4
Memory per node: 16GB
Total storage: 200GB (for persistent volumes)
```

---

## Deployment Methods

Choose the deployment method that best fits your needs:

| Method | Best For | Complexity | Time |
|--------|----------|------------|------|
| Azure Marketplace | Production deployments | Low | 10-15 min |
| Helm Chart | Custom configurations | Medium | 15-20 min |
| Porter Bundle | CI/CD pipelines | Medium | 15-20 min |

---

## Azure Marketplace Deployment

### Step 1: Access the Marketplace

1. Navigate to the [Azure Marketplace listing](https://marketplace.microsoft.com/en-us/product/container/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0?tab=Overview)
2. Click **"Get It Now"** or **"Deploy to Azure"**
3. Sign in to your Azure account

### Step 2: Configure Basic Settings

Fill in the required parameters:

```yaml
Subscription: [Your Azure Subscription]
Resource Group: [Create new or use existing]
Region: [Select region, e.g., East US]
AKS Cluster Name: [Your cluster name or create new]
```

### Step 3: Configure Application Settings

```yaml
# Monitoring Configuration
Prometheus Retention: 15d
Prometheus Storage: 50Gi

# Logging Configuration
Loki Retention: 30d
Loki Storage: 100Gi

# Security Configuration
Enable Falco: true
Enable Trivy: true
Trivy Scan Schedule: "0 2 * * *"  # Daily at 2 AM

# Grafana Configuration
Admin Password: [Set secure password]
Enable Persistence: true
```

### Step 4: Review and Deploy

1. Review all settings in the **"Review + create"** tab
2. Accept terms and conditions
3. Click **"Create"**
4. Wait 10-15 minutes for deployment to complete

### Step 5: Access Deployed Resources

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group <your-resource-group> \
  --name <your-aks-cluster>

# Verify deployment
kubectl get pods -n monitoring
```

---

## Helm Chart Deployment

### Step 1: Prepare Your Environment

```bash
# Clone the repository
git clone https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2.git
cd Kubernetes-DevOps-Suite-v2

# Ensure you're connected to your cluster
kubectl cluster-info
```

### Step 2: Review and Customize Values

```bash
# Review default values
cat helm-chart/values.yaml

# Create custom values file (optional)
cp helm-chart/values.yaml custom-values.yaml
```

**Important values to customize:**

```yaml
# custom-values.yaml
grafana:
  adminPassword: "YourSecurePassword123!"
  persistence:
    enabled: true
    size: 10Gi

prometheus:
  retention: "15d"
  storageSpec:
    volumeClaimTemplate:
      spec:
        resources:
          requests:
            storage: 50Gi

loki:
  persistence:
    enabled: true
    size: 100Gi

falco:
  enabled: true
  customRules:
    enabled: true

trivy:
  enabled: true
  schedule: "0 2 * * *"
```

### Step 3: Create Namespace

```bash
# Create dedicated namespace
kubectl create namespace monitoring

# Verify namespace
kubectl get namespace monitoring
```

### Step 4: Install Prerequisites (if needed)

```bash
# Create service account and RBAC
kubectl apply -f k8s-devops-creds.yaml

# Verify RBAC setup
kubectl get serviceaccount -n monitoring
kubectl get clusterrole | grep k8s-devops
```

### Step 5: Install Helm Chart

```bash
# Install with default values
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --create-namespace

# OR install with custom values
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --create-namespace \
  --values custom-values.yaml

# Watch the deployment
kubectl get pods -n monitoring -w
```

### Step 6: Verify Installation

```bash
# Check all pods are running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring
```

---

## Porter Bundle Deployment

### Step 1: Install Porter

```bash
# Install Porter (if not already installed)
curl -L https://cdn.porter.sh/latest/install-linux.sh | bash

# Verify installation
porter version
```

### Step 2: Prepare Configuration

```bash
# Set your kubeconfig
export KUBECONFIG=~/.kube/config

# Review porter.yaml
cat porter.yaml
```

### Step 3: Install Bundle

```bash
# Install from local bundle
porter install k8s-devops-suite \
  --reference . \
  --param kubeconfig=$KUBECONFIG \
  --param namespace=monitoring

# OR install from registry
porter install k8s-devops-suite \
  --reference ghcr.io/madarsonit-info/k8s-devops-suite:v2.0.0 \
  --param kubeconfig=$KUBECONFIG \
  --param namespace=monitoring
```

### Step 4: Check Installation Status

```bash
# Show installation details
porter installation show k8s-devops-suite

# List all installations
porter list

# View installation logs
porter installation logs k8s-devops-suite
```

---

## Post-Deployment Steps

### 1. Configure Access to Grafana

```bash
# Get Grafana service details
kubectl get svc grafana -n monitoring

# Option A: LoadBalancer (if available)
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Grafana URL: http://$GRAFANA_IP"

# Option B: Port forward
kubectl port-forward svc/grafana 3000:80 -n monitoring
# Access at: http://localhost:3000
```

### 2. Retrieve Grafana Admin Password

```bash
# If you didn't set a custom password
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

### 3. Configure Ingress (Optional)

```yaml
# Create ingress for Grafana
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - grafana.yourdomain.com
    secretName: grafana-tls
  rules:
  - host: grafana.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
```

```bash
kubectl apply -f grafana-ingress.yaml
```

### 4. Import Custom Dashboards

Dashboards are pre-configured, but you can add more:

```bash
# List available dashboards
kubectl get cm -n monitoring | grep dashboard

# Grafana UI: Configuration → Data Sources → Prometheus
# Verify Prometheus datasource is connected
```

### 5. Configure AlertManager

```bash
# Edit AlertManager configuration
kubectl edit cm alertmanager-config -n monitoring

# Restart AlertManager to apply changes
kubectl rollout restart deployment alertmanager -n monitoring
```

### 6. Verify Data Collection

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit: http://localhost:9090/targets

# Check Falco is collecting events
kubectl logs -n monitoring -l app=falco --tail=100

# Verify Trivy scans are scheduled
kubectl get cronjob -n monitoring
```

---

## Verification

### Check Pod Health

```bash
# All pods should be Running or Completed
kubectl get pods -n monitoring

# Check for any issues
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

### Verify Metrics Collection

```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Check metrics in browser
# http://localhost:9090/graph
# Try query: up{job="kubernetes-nodes"}
```

### Verify Log Collection

```bash
# Port forward to Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Login to Grafana
# Go to Explore → Select Loki datasource
# Query: {namespace="monitoring"}
```

### Verify Security Monitoring

```bash
# Check Falco logs
kubectl logs -n monitoring -l app=falco --tail=50

# Check Falco Sidekick (if enabled)
kubectl logs -n monitoring -l app=falcosidekick --tail=50

# Check Trivy scan results
kubectl logs -n monitoring -l app=trivy --tail=100
```

### Test Alerting

```bash
# Trigger a test alert
kubectl run test-alert --image=nginx --restart=Never -n monitoring
kubectl delete pod test-alert -n monitoring

# Check AlertManager
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
# Visit: http://localhost:9093
```

---

## Troubleshooting Deployment

### Pods Not Starting

```bash
# Describe the pod
kubectl describe pod <pod-name> -n monitoring

# Check logs
kubectl logs <pod-name> -n monitoring

# Common issues:
# - Insufficient resources: Check node resources
# - Image pull errors: Check image registry access
# - PVC binding issues: Check storage class
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check storage class
kubectl get storageclass

# If PVC is Pending:
kubectl describe pvc <pvc-name> -n monitoring
```

### Network Issues

```bash
# Check service endpoints
kubectl get endpoints -n monitoring

# Test service connectivity
kubectl run test-curl --image=curlimages/curl -it --rm --restart=Never -- \
  curl -v prometheus.monitoring.svc.cluster.local:9090/-/healthy
```

---

## Upgrade Instructions

### Helm Chart Upgrade

```bash
# Pull latest version
git pull origin main

# Upgrade installation
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --values custom-values.yaml

# Verify upgrade
kubectl rollout status deployment -n monitoring
```

### Porter Bundle Upgrade

```bash
# Upgrade to newer version
porter upgrade k8s-devops-suite \
  --reference ghcr.io/madarsonit-info/k8s-devops-suite:v2.0.5

# Check upgrade status
porter installation show k8s-devops-suite
```

---

## Uninstallation

### Helm Uninstall

```bash
# Uninstall the release
helm uninstall k8s-devops-suite -n monitoring

# Delete namespace (optional)
kubectl delete namespace monitoring

# Delete PVCs (if not auto-deleted)
kubectl delete pvc --all -n monitoring
```

### Porter Uninstall

```bash
# Uninstall bundle
porter uninstall k8s-devops-suite

# Verify removal
porter list
```

---

## Next Steps

- [Configuration Guide](./configuration.md) - Customize your deployment
- [Troubleshooting Guide](./troubleshooting.md) - Resolve common issues
- [Security Best Practices](./security.md) - Harden your deployment
---

