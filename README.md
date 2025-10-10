# Madarson IT Kubernetes DevOps Suite v2
## Overview
Production-ready DevOps toolkit for Kubernetes with enterprise-grade monitoring, security, and logging capabilities.

## What's Included (Enabled by Default)
### Monitoring & Observability
- **Grafana** - Customizable dashboards on port 3000
- **Prometheus** - Metrics collection and alerting
- **Alertmanager** - Intelligent alert routing
- **Node Exporter** - Infrastructure metrics
- **Kube-state-metrics** - Kubernetes object metrics

### Logging
- **Loki** - Centralized log aggregation
- **Promtail** - Automatic log collection from all pods

### Security
- **Trivy** - Automated vulnerability scanning (daily)
- **Falco** - Runtime security monitoring (optional, requires privileged pods)

## System Requirements

### Minimum (Core Features Only)
- 4 CPU cores
- 8GB RAM
- 20GB storage
- Kubernetes 1.24+

### Recommended (Full Stack)
- 8 CPU cores
- 16GB RAM
- 50GB storage
- Kubernetes 1.24+

## Quick Start

### 1. Deploy from Azure Marketplace
1. Search for "Madarson IT Kubernetes DevOps Suite" in Azure Marketplace
2. Select your existing AKS cluster
3. Set Grafana admin password (required, 8+ characters)
4. Choose features to enable (monitoring/security)
5. Deploy (takes 5-10 minutes)

### 2. Access Your Dashboards

After deployment completes:
```bash
# Get service external IPs
kubectl get svc -n devops-suite

# Access dashboards
# Manager: http://<MANAGER-EXTERNAL-IP>:8080
# Grafana: http://<GRAFANA-EXTERNAL-IP>:3000
Default Credentials:
Grafana: admin / [password you set during deployment]

3. Verify Installation
bash# Check all pods are running
kubectl get pods -n devops-suite

# All pods should show "Running" status
Features
Grafana Dashboards
Access pre-configured dashboards for:
Cluster resource usage
Pod/namespace metrics
Persistent volume utilization
Security alerts (if Falco enabled)

Prometheus Metrics
300+ built-in metrics including:
CPU/Memory usage
Network I/O
Disk utilization
Custom application metrics

Loki Logging
Automatic log collection from all pods
Searchable log aggregation
Integrated with Grafana for visualization

Trivy Security Scanning
Daily automated scans
Container image vulnerability detection
Results available in reports

Optional: Enable Falco Runtime Security
Falco requires privileged pods. 
To enable:
Ensure your AKS cluster allows privileged pods
Enable during deployment or upgrade:

bash
helm upgrade k8s-devops-suite <chart> \
  -n devops-suite \
  --set security.falco.enabled=true
Note: Falco requires additional resources (2 CPU, 2GB RAM)

Troubleshooting
Pods not starting
bash# Check pod status
kubectl describe pod <pod-name> -n devops-suite

# Common issues:
# - Insufficient CPU/memory: Scale up cluster
# - Image pull errors: Check ACR access
Can't access Grafana
bash# Check service has external IP
kubectl get svc k8s-devops-suite-grafana -n devops-suite

# If <pending>, wait 2-3 minutes for load balancer provisioning
Forgot Grafana password
The password is set during deployment and cannot be retrieved. 
To reset:
bash
kubectl delete secret k8s-devops-suite-grafana-secret -n devops-suite
# Then redeploy or manually create new secret

Support
Email: info@madarsonit.com
Issues: Report via Azure Marketplace support

Version History
v2.0.2 (Current)
Customer-configurable Grafana password
Enhanced Falco security rules
Production-ready defaults
Loki logging enabled by default

v2.0.1
Added Loki logging stack
Fixed Grafana deployment issues
Enhanced monitoring capabilities

v1.0.6
Initial stable release
Core monitoring features

License
See LICENSE file in package
