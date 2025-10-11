# Architecture Documentation

## System Architecture

The K8s DevOps Suite follows a distributed architecture pattern optimized for Kubernetes environments.

## Component Diagram
┌─────────────────────────────────────────────────────────┐
│                     Users / DevOps Team                  │
└────────────────────┬────────────────────────────────────┘
│
▼
┌──────────────────────┐
│   Ingress/LoadBalancer│
└──────────┬───────────┘
│
┌────────────┴────────────┐
│                         │
▼                         ▼
┌───────────────┐         ┌──────────────┐
│    Grafana    │◄────────┤  Prometheus  │
│  (Frontend)   │         │  (Metrics)   │
└───────┬───────┘         └──────┬───────┘
│                        │
│                 ┌──────┴────────┐
│                 │               │
│                 ▼               ▼
│         ┌──────────────┐ ┌────────────┐
│         │ AlertManager │ │  Exporters │
│         └──────────────┘ └────────────┘
│
▼
┌──────────────┐
│     Loki     │
│   (Logs)     │
└──────┬───────┘
│
▼
┌──────────────┐
│   Promtail   │
│ (DaemonSet)  │
└──────────────┘

## Data Flow

### Metrics Collection
1. Prometheus scrapes metrics from targets
2. Metrics stored in TSDB with configured retention
3. Grafana queries Prometheus for visualization
4. AlertManager evaluates rules and sends notifications

### Log Collection
1. Promtail tails logs from all pods
2. Logs pushed to Loki
3. Loki stores logs with labels
4. Grafana queries Loki for log exploration

### Security Monitoring
1. Falco monitors system calls
2. Security events generated for violations
3. Events forwarded to Falcosidekick
4. Alerts sent to configured channels

## Storage Architecture

- **Prometheus**: Time-series database on persistent volume
- **Loki**: Log chunks and index on persistent volume
- **Grafana**: Dashboard definitions and user data
- **Separate PVCs**: Isolation and independent scaling

## Network Architecture

- **Service Mesh**: Standard Kubernetes services
- **DNS**: Internal cluster DNS for service discovery
- **Ingress**: Optional external access via ingress controller
- **Network Policies**: Optional traffic control

## Security Architecture

- **RBAC**: Role-based access control for all components
- **Secrets**: Kubernetes secrets for sensitive data
- **TLS**: Optional TLS for external communication
- **Pod Security**: Security contexts and policies

For detailed deployment instructions, see [Deployment Guide](deployment-guide.md).
