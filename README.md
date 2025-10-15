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
.
├── CHANGELOG.md              # Version history and changes
├── CONTRIBUTING.md           # Contribution guidelines
├── CUSTOMIZATION_GUIDE.md    # Customization instructions
├── LICENSE                   # License information
├── README.md                 # This file
├── SECURITY.md              # Security policies and reporting
├── project-overview.md      # Detailed project overview
├── azure/                   # Azure-specific resources
│   ├── scripts/             # Azure deployment scripts
│   │   └── deploy.sh        # Main deployment script
│   └── templates/           # Azure ARM templates
│       └── arm-template.json
├── docs/                    # Documentation
│   ├── architecture.md      # System architecture
│   ├── best-practices.md    # Best practices guide
│   ├── configuration.md     # Configuration reference
│   ├── deployment-guide.md  # Deployment instructions
│   ├── security.md          # Security guidelines
│   └── troubleshooting.md   # Troubleshooting guide
├── examples/                # Example configurations
│   ├── advanced-config/     # Advanced setup examples
│   └── basic-setup/         # Basic setup examples
│       ├── README.md
│       ├── deploy.sh
│       ├── values.yaml
│       └── verify.sh
└── kubernetes/              # Kubernetes resources
    ├── helm/                # Helm charts
    └── manifests/           # Kubernetes manifests
        ├── deployment.yaml
        └── service.yaml
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

### Option 2: Azure Deployment Script

```bash
# Clone the repository
git clone https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2.git
cd Kubernetes-DevOps-Suite-v2

# Run Azure deployment script
./azure/scripts/deploy.sh \
  --resource-group <your-rg> \
  --cluster-name <your-cluster> \
  --location <azure-region>
```

### Option 3: Helm Chart Installation

```bash
# Install using Helm
helm install k8s-devops-suite ./kubernetes/helm \
  --namespace monitoring \
  --create-namespace \
  --values ./examples/basic-setup/values.yaml

# Verify installation
kubectl get pods -n monitoring
```

### Option 4: Basic Setup Example

```bash
# Navigate to basic setup example
cd examples/basic-setup

# Review and customize values.yaml
vim values.yaml

# Deploy using the example script
./deploy.sh

# Verify deployment
./verify.sh
```

---

## ⚙️ Configuration

### Custom Values

Edit your values file to customize the deployment:

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
  rules: custom
```

See [CUSTOMIZATION_GUIDE.md](./CUSTOMIZATION_GUIDE.md) for detailed customization options.

### Security Configuration

For security best practices and hardening recommendations, see:
- [docs/security.md](./docs/security.md) - Security guidelines
- [SECURITY.md](./SECURITY.md) - Security policies

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

Comprehensive documentation is available in the `/docs` directory:

- **[Architecture](./docs/architecture.md)** - System architecture and design
- **[Deployment Guide](./docs/deployment-guide.md)** - Detailed installation instructions
- **[Configuration Guide](./docs/configuration.md)** - Configuration options and reference
- **[Best Practices](./docs/best-practices.md)** - Operational best practices
- **[Security](./docs/security.md)** - Security guidelines and hardening
- **[Troubleshooting](./docs/troubleshooting.md)** - Common issues and solutions
- **[Project Overview](./project-overview.md)** - High-level overview and goals

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

For detailed security information, see [docs/security.md](./docs/security.md).

---

## 🧪 Testing

```bash
# Run verification script (basic setup)
cd examples/basic-setup
./verify.sh

# Check component health
kubectl get pods -n monitoring
kubectl get svc -n monitoring
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

For detailed troubleshooting, see [docs/troubleshooting.md](./docs/troubleshooting.md).

---

## 📈 Version History

- **v2.0.5** - Latest stable release
- **v2.0.1** - Bug fixes and improvements
- **v2.0.0** - Major release with enhanced features
- **v1.0.6** - Previous stable version

See [CHANGELOG.md](./CHANGELOG.md) for detailed version history.

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for details on:
- How to submit issues
- How to submit pull requests
- Code style guidelines
- Development setup

---

## 🆘 Support

- **Azure Marketplace Support**: [Contact via Azure Portal](https://portal.azure.com/#create/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0madarson-k8s-devops-suite-2-0-0)
- **GitHub Issues**: [Report bugs or request features](https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2/issues)
- **Documentation**: Check the [/docs](./docs) folder in this repository
- **Security Issues**: See [SECURITY.md](./SECURITY.md) for security reporting

---

## 📄 License

See [LICENSE](./LICENSE) file for details.

---

## 🔗 Related Links

- **Azure Marketplace**: [Product Listing](https://marketplace.microsoft.com/en-us/product/container/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0?tab=Overview)
- **Azure Portal Deployment**: [Direct Deploy Link](https://portal.azure.com/#create/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0madarson-k8s-devops-suite-2-0-0)
- **Madarson IT LLC**: [Company Website](https://madarsonit.com)

---

## 🏢 About

**Publisher:** Madarson IT LLC  
**Version:** 2.0.5  
**Last Updated:** October 2025  
**Category:** Kubernetes DevOps & Observability

---

**⭐ If this solution helps your organization, please star this repository!**
