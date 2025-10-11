# Madarson Kubernetes DevOps Suite v2.0

A comprehensive, production-ready Kubernetes DevOps platform that combines monitoring, logging, security, and observability tools into a single, easy-to-deploy solution.

## 🚀 Quick Deploy

Deploy directly from Azure Marketplace:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0madarson-k8s-devops-suite-2-0-0)

**Azure Marketplace:** [View Product Details](https://marketplace.microsoft.com/en-us/product/container/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0?tab=Overview)

---

## 📋 Overview

The Madarson K8s DevOps Suite is an all-in-one observability and security platform for Kubernetes environments. It provides complete visibility into your cluster operations with integrated monitoring, logging, security scanning, and runtime threat detection.

### 🎯 Key Components

- **📊 Prometheus Stack** - Metrics collection and alerting with AlertManager
- **📈 Grafana** - Visualization dashboards with pre-configured panels
- **📝 Loki + Promtail** - Log aggregation and querying
- **🔒 Falco** - Runtime security and threat detection
- **🛡️ Trivy** - Vulnerability scanning for container images
- **📡 Kube-State-Metrics** - Kubernetes object metrics
- **💻 Node Exporter** - Hardware and OS metrics

---

## 🏗️ Architecture

This suite deploys a complete observability stack across your Kubernetes cluster:

```
┌─────────────────────────────────────────────────────┐
│                 Grafana Dashboard                    │
│         (Visualization & Alerting UI)                │
└──────────────┬──────────────┬───────────────────────┘
               │              │
       ┌───────▼──────┐  ┌───▼──────────┐
       │  Prometheus  │  │     Loki     │
       │  (Metrics)   │  │    (Logs)    │
       └───────┬──────┘  └───▲──────────┘
               │             │
    ┌──────────┼─────────────┼──────────┐
    │          │             │          │
┌───▼───┐  ┌──▼──┐      ┌───┴────┐  ┌──▼────┐
│ Falco │  │Node │      │Promtail│  │Trivy  │
│       │  │Expo │      │        │  │Scanner│
└───────┘  └─────┘      └────────┘  └───────┘
```

---

## 📦 Repository Structure

```
├── helm-chart/              # Main Helm chart for deployment
│   ├── templates/           # Kubernetes manifests
│   │   ├── prometheus/      # Prometheus monitoring stack
│   │   ├── grafana/         # Grafana dashboards & configs
│   │   ├── logging/         # Loki & Promtail
│   │   ├── falco/           # Runtime security
│   │   └── trivy/           # Vulnerability scanning
│   ├── values.yaml          # Configuration values
│   └── Chart.yaml           # Chart metadata
├── marketplace-assets/      # Azure Marketplace resources
│   ├── logos/               # Product logos
│   ├── screenshots/         # Product screenshots
│   └── documents/           # Marketing documentation
├── scripts/                 # Deployment & utility scripts
├── docs/                    # Documentation
├── tests/                   # Test suites
│   ├── unit/                # Unit tests
│   ├── integration/         # Integration tests
│   └── e2e/                 # End-to-end tests
├── mainTemplate.json        # Azure ARM template
├── createUIDefinition.json  # Azure Portal UI definition
└── porter.yaml              # Porter bundle definition
```

---

## 🛠️ Prerequisites

- **Azure Subscription** with appropriate permissions
- **Azure Kubernetes Service (AKS)** cluster (or create during deployment)
  - Minimum 3 nodes recommended
  - At least 4 vCPUs and 16GB RAM per node
- **kubectl** configured (for manual deployment)
- **Helm 3.x** (for manual deployment)

---

## 🚀 Deployment Options

### Option 1: Azure Marketplace (Recommended)

1. Click the **Deploy to Azure** button above
2. Configure your deployment parameters:
   - Resource Group
   - AKS Cluster (existing or new)
   - Storage configuration
   - Retention policies
3. Review and create the deployment
4. Access Grafana dashboard after deployment completes

### Option 2: Helm Chart Installation

```bash
# Add credentials (if required)
kubectl create -f k8s-devops-creds.yaml

# Install the Helm chart
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --create-namespace \
  --values helm-chart/values.yaml

# Verify installation
kubectl get pods -n monitoring
```

### Option 3: Porter Bundle

```bash
# Install using Porter
porter install k8s-devops-suite \
  --reference ghcr.io/madarsonit-info/k8s-devops-suite:v2.0.0 \
  --param kubeconfig=$KUBECONFIG

# Check bundle status
porter installation show k8s-devops-suite
```

---

## ⚙️ Configuration

### Custom Values

Edit `helm-chart/values.yaml` to customize:

```yaml
# Example customizations
prometheus:
  retention: 15d
  storage: 50Gi
  
grafana:
  adminPassword: "your-secure-password"
  persistence: true
  
loki:
  retention: 30d
  storage: 100Gi

falco:
  enabled: true
  rules: custom  # Use custom rules from helm-chart/rules/
```

### Security Rules

Custom Falco security rules can be added to:
- `helm-chart/rules/devops-security.yaml`
- `falco-rules.yaml`

---

## 📊 Accessing Dashboards

### Grafana

```bash
# Get Grafana URL
kubectl get svc grafana -n monitoring

# Port forward (if needed)
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Default credentials
Username: admin
Password: (check your values.yaml or secret)
```

### Prometheus

```bash
# Access Prometheus UI
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
```

### AlertManager

```bash
# Access AlertManager UI
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
```

---

## 📖 Documentation

- **[Deployment Guide](./docs/deployment-guide.md)** - Detailed installation instructions
- **[Configuration Guide](./docs/configuration.md)** - Customization options
- **[Troubleshooting](./docs/troubleshooting.md)** - Common issues and solutions
- **[Security Best Practices](./docs/security.md)** - Hardening recommendations
- **[Project Overview](./project-overview.md)** - Architecture and design decisions

---

## 🔍 Monitoring Features

### Metrics Collected
- Cluster resource utilization (CPU, Memory, Disk)
- Pod and container metrics
- Node health and performance
- Kubernetes API server metrics
- Custom application metrics

### Pre-configured Dashboards
- Kubernetes Cluster Overview
- Node Exporter Full
- Pod Resource Usage
- Falco Security Events
- Loki Log Exploration

### Alerting Rules
- High CPU/Memory usage
- Pod crash loops
- Disk space warnings
- Security policy violations
- Node unavailability

---

## 🔒 Security Features

### Falco Runtime Security
- Detects anomalous activity in applications
- Monitors system calls for suspicious behavior
- Alerts on policy violations
- Custom rule support

### Trivy Vulnerability Scanning
- Automated container image scanning
- CVE detection and reporting
- Integration with CI/CD pipelines
- Scheduled scans via CronJob

---

## 🧪 Testing

```bash
# Run unit tests
make test-unit

# Run integration tests
make test-integration

# Run end-to-end tests
make test-e2e
```

---

## 🐛 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

### Common Issues

**Pods stuck in Pending:**
- Check node resources: `kubectl describe nodes`
- Verify PVC status: `kubectl get pvc -n monitoring`

**Prometheus not scraping metrics:**
- Check service monitors: `kubectl get servicemonitor -n monitoring`
- Verify RBAC permissions: `kubectl get clusterrole | grep prometheus`

**Grafana dashboards not loading:**
- Check datasource configuration
- Verify Prometheus connectivity
- Review Grafana logs

---

## 📈 Version History

- **v2.0.2** - Latest stable release
- **v2.0.1** - Bug fixes and improvements
- **v2.0.0** - Major release with enhanced features
- **v1.0.6** - Previous stable version

See [releases](../../releases) for detailed changelogs.

---

## 🤝 Support

- **Azure Marketplace Support**: [Contact via Azure Portal](https://portal.azure.com/#create/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0madarson-k8s-devops-suite-2-0-0)
- **GitHub Issues**: [Report bugs or request features](https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2/issues)
- **Documentation**: Check the `/docs` folder in this repository

---

## 📄 License


---

## 🔗 Related Links

- **Azure Marketplace**: [Product Listing](https://marketplace.microsoft.com/en-us/product/container/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0?tab=Overview)
- **Azure Portal Deployment**: [Direct Deploy Link](https://portal.azure.com/#create/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0madarson-k8s-devops-suite-2-0-0)
- **Madarson IT LLC**: [Company Website](https://madarson.com)

---

## 🏢 About

**Publisher:** Madarson IT LLC  
**Version:** 2.0.2  
**Last Updated:** October 2025  
**Category:** Kubernetes DevOps & Observability

---

**⭐ If this solution helps your organization, please star this repository!**
