# Basic Setup Example

This example demonstrates a basic deployment of the K8s DevOps Suite suitable for small to medium-sized development or staging environments.

## Overview

This configuration provides:
- Prometheus with 7-day retention
- Grafana with pre-configured dashboards
- Loki for log aggregation (7-day retention)
- Falco for security monitoring
- Minimal resource requirements

## Files Included

- `values.yaml` - Helm values for basic setup
- `deploy.sh` - Deployment script
- `verify.sh` - Verification script

## Prerequisites

- Kubernetes cluster with at least 3 nodes
- 4 vCPUs and 8GB RAM per node
- 100GB available storage
- kubectl configured
- Helm 3.x installed

## Quick Start

```bash
# 1. Navigate to this directory
cd examples/basic-setup

# 2. Review and customize values
cat values.yaml

# 3. Deploy
./deploy.sh

# 4. Verify deployment
./verify.sh

# 5. Access Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring
# Open: http://localhost:3000
# Default credentials: admin / prom-operator
```

## Configuration Details

### Resource Allocation

```yaml
Total CPU Request: ~2 vCPUs
Total Memory Request: ~6GB
Total Storage: ~100GB
```

### Component Settings

**Prometheus:**
- Retention: 7 days
- Storage: 30GB
- Scrape interval: 30s
- No high availability

**Grafana:**
- Single replica
- Storage: 5GB
- Pre-loaded dashboards
- Default admin password

**Loki:**
- Retention: 7 days
- Storage: 40GB
- Single instance
- Basic configuration

**Promtail:**
- DaemonSet on all nodes
- Collects all pod logs
- Labels: namespace, pod, container

**Falco:**
- Default rules enabled
- Basic security monitoring
- Console output

## Accessing Components

### Grafana Dashboard

```bash
# Port forward
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Get admin password
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d

# URL: http://localhost:3000
```

### Prometheus UI

```bash
# Port forward
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# URL: http://localhost:9090
```

### AlertManager

```bash
# Port forward
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring

# URL: http://localhost:9093
```

## Common Tasks

### View Logs in Grafana

1. Open Grafana: http://localhost:3000
2. Go to Explore
3. Select Loki datasource
4. Query: `{namespace="monitoring"}`

### Check Metrics

1. Open Grafana: http://localhost:3000
2. Go to Dashboards
3. Select "Kubernetes Cluster Overview"

### View Security Events

```bash
# Check Falco logs
kubectl logs -n monitoring -l app=falco --tail=50
```

## Customization

### Change Retention Period

Edit `values.yaml`:

```yaml
prometheus:
  retention: 14d  # Change to 14 days

loki:
  retention:
    period: 336h  # Change to 14 days
```

### Adjust Resource Limits

Edit `values.yaml`:

```yaml
prometheus:
  resources:
    limits:
      memory: 4Gi  # Increase if needed
```

### Add Custom Dashboards

Place dashboard JSON files in `custom-dashboards/` and they will be automatically loaded.

## Monitoring Your Applications

### Add Metrics Endpoint

Annotate your pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### Add Custom Alerts

Create a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-alerts
  namespace: monitoring
data:
  alerts.yaml: |
    groups:
      - name: custom
        rules:
          - alert: HighErrorRate
            expr: rate(http_requests_total{status="500"}[5m]) > 0.1
            annotations:
              summary: "High error rate detected"
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n monitoring

# Describe problematic pod
kubectl describe pod <pod-name> -n monitoring

# Check logs
kubectl logs <pod-name> -n monitoring
```

### No Metrics Showing

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit: http://localhost:9090/targets

# Verify services
kubectl get svc -n monitoring
```

### Grafana Not Loading

```bash
# Check Grafana logs
kubectl logs -n monitoring -l app=grafana

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

## Upgrading

```bash
# Pull latest changes
git pull origin main

# Upgrade installation
helm upgrade k8s-devops-suite ../../helm-chart \
  --namespace monitoring \
  --values values.yaml

# Verify upgrade
./verify.sh
```

## Uninstalling

```bash
# Remove the installation
helm uninstall k8s-devops-suite -n monitoring

# Delete namespace
kubectl delete namespace monitoring

# Delete PVCs (if you want to remove data)
kubectl delete pvc --all -n monitoring
```

## Next Steps

- Review [Advanced Setup](../advanced-config/) for production configurations
- Check [Configuration Guide](../../docs/configuration.md) for all options
- See [Troubleshooting Guide](../../docs/troubleshooting.md) if you encounter issues

## Support

- [Azure Marketplace Support](https://portal.azure.com/)
