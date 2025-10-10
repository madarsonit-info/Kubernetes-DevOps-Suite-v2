# Configuration Guide

## Table of Contents
- [Overview](#overview)
- [Helm Values Configuration](#helm-values-configuration)
- [Prometheus Configuration](#prometheus-configuration)
- [Grafana Configuration](#grafana-configuration)
- [Loki & Promtail Configuration](#loki--promtail-configuration)
- [Falco Security Configuration](#falco-security-configuration)
- [Trivy Scanner Configuration](#trivy-scanner-configuration)
- [Storage Configuration](#storage-configuration)
- [Resource Limits](#resource-limits)
- [Advanced Configuration](#advanced-configuration)

---

## Overview

The K8s DevOps Suite can be configured through Helm values or by directly modifying Kubernetes resources. This guide covers all major configuration options.

### Configuration Files

- **`helm-chart/values.yaml`** - Main configuration file
- **`helm-chart/rules/devops-security.yaml`** - Custom Falco rules
- **`falco-rules.yaml`** - Additional Falco rules
- **`createUIDefinition.json`** - Azure Portal UI configuration

---

## Helm Values Configuration

### Creating Custom Values File

```bash
# Copy default values
cp helm-chart/values.yaml my-values.yaml

# Edit your custom values
nano my-values.yaml

# Install with custom values
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --values my-values.yaml
```

### Global Settings

```yaml
# Global configuration
global:
  namespace: monitoring
  storageClass: default  # or azure-disk, managed-premium
  imageRegistry: docker.io
  imagePullSecrets: []
```

---

## Prometheus Configuration

### Basic Prometheus Settings

```yaml
prometheus:
  enabled: true
  
  # Data retention
  retention: 15d
  retentionSize: 45GB
  
  # Storage configuration
  storageSpec:
    volumeClaimTemplate:
      spec:
        storageClassName: managed-premium
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
  
  # Resource limits
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 8Gi
  
  # Replica configuration
  replicas: 1
  
  # Scrape interval
  scrapeInterval: 30s
  evaluationInterval: 30s
```

### Custom Scrape Configs

```yaml
prometheus:
  additionalScrapeConfigs:
    - job_name: 'custom-app'
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
```

### AlertManager Configuration

```yaml
alertmanager:
  enabled: true
  
  # Storage for AlertManager
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: default
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
  
  # Alert routing configuration
  config:
    global:
      resolve_timeout: 5m
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      routes:
        - match:
            severity: critical
          receiver: 'critical-alerts'
          continue: true
    
    receivers:
      - name: 'default'
        email_configs:
          - to: 'team@example.com'
            from: 'alertmanager@example.com'
            smarthost: 'smtp.example.com:587'
            auth_username: 'alertmanager@example.com'
            auth_password: 'your-password'
      
      - name: 'critical-alerts'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
            channel: '#alerts-critical'
            title: 'Critical Alert'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Custom Alert Rules

Create file: `custom-alerts.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-custom-rules
  namespace: monitoring
data:
  custom-rules.yaml: |
    groups:
      - name: custom_alerts
        interval: 30s
        rules:
          - alert: HighPodMemory
            expr: sum(container_memory_usage_bytes{pod!=""}) by (pod, namespace) / sum(container_spec_memory_limit_bytes{pod!=""}) by (pod, namespace) > 0.9
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Pod {{ $labels.pod }} high memory usage"
              description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of memory limit."
          
          - alert: PodCrashLooping
            expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Pod {{ $labels.pod }} is crash looping"
              description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently."
```

Apply custom rules:
```bash
kubectl apply -f custom-alerts.yaml
```

---

## Grafana Configuration

### Basic Grafana Settings

```yaml
grafana:
  enabled: true
  
  # Admin credentials
  adminUser: admin
  adminPassword: "YourSecurePassword123!"
  
  # Persistence
  persistence:
    enabled: true
    storageClassName: default
    size: 10Gi
  
  # Resource limits
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  # Datasources (pre-configured)
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      access: proxy
      isDefault: true
    
    - name: Loki
      type: loki
      url: http://loki:3100
      access: proxy
```

### Custom Grafana Configuration

```yaml
grafana:
  # Additional environment variables
  env:
    GF_SERVER_ROOT_URL: "https://grafana.yourdomain.com"
    GF_SECURITY_ADMIN_PASSWORD: "admin"
    GF_USERS_ALLOW_SIGN_UP: "false"
    GF_AUTH_ANONYMOUS_ENABLED: "true"
    GF_AUTH_ANONYMOUS_ORG_ROLE: "Viewer"
  
  # SMTP configuration for alerts
  smtp:
    enabled: true
    host: "smtp.gmail.com:587"
    user: "your-email@gmail.com"
    password: "your-app-password"
    from_address: "grafana@yourdomain.com"
    from_name: "Grafana Alerts"
```

### Custom Dashboards

Place custom dashboard JSON files in `helm-chart/templates/grafana/dashboards/`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-custom-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  custom-dashboard.json: |
    {
      "dashboard": {
        "title": "Custom Application Metrics",
        "panels": [
          {
            "title": "Request Rate",
            "targets": [
              {
                "expr": "rate(http_requests_total[5m])"
              }
            ]
          }
        ]
      }
    }
```

---

## Loki & Promtail Configuration

### Loki Configuration

```yaml
loki:
  enabled: true
  
  # Data retention
  retention:
    enabled: true
    period: 720h  # 30 days
  
  # Storage configuration
  persistence:
    enabled: true
    storageClassName: default
    size: 100Gi
  
  # Resource limits
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  # Loki configuration
  config:
    auth_enabled: false
    
    ingester:
      chunk_idle_period: 3m
      chunk_block_size: 262144
      chunk_retain_period: 1m
      max_transfer_retries: 0
      lifecycler:
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
    
    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20
    
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h
    
    storage_config:
      boltdb_shipper:
        active_index_directory: /data/loki/boltdb-shipper-active
        cache_location: /data/loki/boltdb-shipper-cache
        cache_ttl: 24h
        shared_store: filesystem
      filesystem:
        directory: /data/loki/chunks
```

### Promtail Configuration

```yaml
promtail:
  enabled: true
  
  # Deploy as DaemonSet
  daemonset:
    enabled: true
  
  # Resource limits
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  
  # Promtail configuration
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
    
    positions:
      filename: /tmp/positions.yaml
    
    scrape_configs:
      # Kubernetes pod logs
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: __host__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - action: replace
            replacement: $1
            separator: /
            source_labels:
              - __meta_kubernetes_namespace
              - __meta_kubernetes_pod_name
            target_label: job
          - action: replace
            source_labels:
              - __meta_kubernetes_namespace
            target_label: namespace
          - action: replace
            source_labels:
              - __meta_kubernetes_pod_name
            target_label: pod
          - action: replace
            source_labels:
              - __meta_kubernetes_pod_container_name
            target_label: container
          - replacement: /var/log/pods/*$1/*.log
            separator: /
            source_labels:
              - __meta_kubernetes_pod_uid
              - __meta_kubernetes_pod_container_name
            target_label: __path__
```

---

## Falco Security Configuration

### Basic Falco Settings

```yaml
falco:
  enabled: true
  
  # Image configuration
  image:
    repository: falcosecurity/falco
    tag: latest
  
  # Resource limits
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  
  # Custom rules
  customRules:
    enabled: true
    rules: |
      - rule: Unauthorized Process in Container
        desc: Detect unauthorized processes running in containers
        condition: >
          spawned_process and
          container and
          not proc.name in (allowed_processes)
        output: >
          Unauthorized process started in container
          (user=%user.name process=%proc.name container=%container.name)
        priority: WARNING
```

### Falco Sidekick Configuration

```yaml
falcosidekick:
  enabled: true
  
  # Output integrations
  config:
    slack:
      webhookurl: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
      minimumpriority: "warning"
    
    elasticsearch:
      hostport: "http://elasticsearch:9200"
      index: "falco"
      minimumpriority: "warning"
    
    webhook:
      address: "http://your-webhook-endpoint"
      minimumpriority: "notice"
```

### Custom Falco Rules

Edit `helm-chart/rules/devops-security.yaml`:

```yaml
- rule: Sensitive File Access
  desc: Detect access to sensitive files
  condition: >
    open_read and
    fd.name in (/etc/shadow, /etc/sudoers, /root/.ssh/id_rsa)
  output: >
    Sensitive file accessed
    (user=%user.name file=%fd.name container=%container.name)
  priority: CRITICAL

- rule: Unexpected Network Connection
  desc: Detect unexpected outbound connections
  condition: >
    outbound and
    not fd.sip in (allowed_ips) and
    container
  output: >
    Unexpected network connection from container
    (container=%container.name dest=%fd.rip port=%fd.rport)
  priority: WARNING

- rule: Privilege Escalation Attempt
  desc: Detect privilege escalation attempts
  condition: >
    spawned_process and
    proc.name in (sudo, su) and
    container
  output: >
    Privilege escalation attempt detected
    (user=%user.name process=%proc.cmdline container=%container.name)
  priority: CRITICAL
```

---

## Trivy Scanner Configuration

### Basic Trivy Settings

```yaml
trivy:
  enabled: true
  
  # Scan schedule (cron format)
  schedule: "0 2 * * *"  # Daily at 2 AM
  
  # Scan configuration
  scanConfig:
    severity: "CRITICAL,HIGH,MEDIUM"
    vuln-type: "os,library"
    format: "json"
    output: "/reports/scan-results.json"
  
  # Resource limits
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### Advanced Trivy Configuration

```yaml
trivy:
  # Scan targets
  scanTargets:
    - "nginx:latest"
    - "redis:latest"
    - "postgres:14"
  
  # Registry authentication
  registryAuth:
    - registry: "private-registry.io"
      username: "user"
      passwordSecret:
        name: "registry-secret"
        key: "password"
  
  # Report storage
  reports:
    persistence:
      enabled: true
      storageClassName: default
      size: 5Gi
```

---

## Storage Configuration

### Azure Disk Storage

```yaml
storage:
  storageClass: managed-premium
  
  # Prometheus storage
  prometheus:
    size: 50Gi
    accessModes:
      - ReadWriteOnce
  
  # Grafana storage
  grafana:
    size: 10Gi
    accessModes:
      - ReadWriteOnce
  
  # Loki storage
  loki:
    size: 100Gi
    accessModes:
      - ReadWriteOnce
  
  # AlertManager storage
  alertmanager:
    size: 10Gi
    accessModes:
      - ReadWriteOnce
```

### Azure Files Storage (for shared access)

```yaml
storage:
  storageClass: azurefile
  
  sharedStorage:
    enabled: true
    size: 50Gi
    accessModes:
      - ReadWriteMany
```

---

## Resource Limits

### Recommended Resource Allocation

```yaml
resources:
  # Prometheus
  prometheus:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 8Gi
  
  # Grafana
  grafana:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  # Loki
  loki:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  # Promtail (per node)
  promtail:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  
  # Falco (per node)
  falco:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  
  # Node Exporter (per node)
  nodeExporter:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

---

## Advanced Configuration

### High Availability Setup

```yaml
highAvailability:
  enabled: true
  
  prometheus:
    replicas: 2
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
                - key: app
                  operator: In
                  values:
                    - prometheus
            topologyKey: kubernetes.io/hostname
  
  grafana:
    replicas: 2
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - grafana
              topologyKey: kubernetes.io/hostname
  
  loki:
    replicas: 3
    replicationFactor: 3
```

### Network Policies

```yaml
networkPolicies:
  enabled: true
  
  # Allow Prometheus to scrape metrics
  prometheus:
    ingress:
      - from:
        - podSelector:
            matchLabels:
              app: prometheus
        ports:
          - protocol: TCP
            port: 9090
  
  # Allow Grafana to access datasources
  grafana:
    egress:
      - to:
        - podSelector:
            matchLabels:
              app: prometheus
        ports:
          - protocol: TCP
            port: 9090
      - to:
        - podSelector:
            matchLabels:
              app: loki
        ports:
          - protocol: TCP
            port: 3100
```

### Node Selectors and Tolerations

```yaml
# Deploy monitoring on specific nodes
nodeSelector:
  node-role.kubernetes.io/monitoring: "true"

# Tolerate monitoring taints
tolerations:
  - key: "monitoring"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"

# Example for specific components
prometheus:
  nodeSelector:
    workload-type: monitoring
  tolerations:
    - key: monitoring
      operator: Exists
      effect: NoSchedule
```

### Ingress Configuration

```yaml
ingress:
  enabled: true
  className: nginx
  
  # Grafana ingress
  grafana:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: grafana.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.yourdomain.com
  
  # Prometheus ingress (with authentication)
  prometheus:
    enabled: true
    annotations:
      nginx.ingress.kubernetes.io/auth-type: basic
      nginx.ingress.kubernetes.io/auth-secret: prometheus-basic-auth
      nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
    hosts:
      - host: prometheus.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: prometheus-tls
        hosts:
          - prometheus.yourdomain.com
```

### Service Monitor Configuration

```yaml
serviceMonitors:
  # Monitor custom applications
  customApp:
    enabled: true
    selector:
      matchLabels:
        app: my-custom-app
    endpoints:
      - port: metrics
        interval: 30s
        path: /metrics
```

### Pod Security Policies

```yaml
podSecurityPolicy:
  enabled: true
  
  spec:
    privileged: false
    allowPrivilegeEscalation: false
    requiredDropCapabilities:
      - ALL
    volumes:
      - 'configMap'
      - 'emptyDir'
      - 'projected'
      - 'secret'
      - 'downwardAPI'
      - 'persistentVolumeClaim'
    hostNetwork: false
    hostIPC: false
    hostPID: false
    runAsUser:
      rule: 'MustRunAsNonRoot'
    seLinux:
      rule: 'RunAsAny'
    supplementalGroups:
      rule: 'RunAsAny'
    fsGroup:
      rule: 'RunAsAny'
```

### Backup Configuration

```yaml
backup:
  enabled: true
  
  # Velero backup schedule
  schedule: "0 3 * * *"  # Daily at 3 AM
  
  # What to backup
  includedNamespaces:
    - monitoring
  
  # Retention
  ttl: 720h  # 30 days
  
  # Storage location
  storageLocation:
    provider: azure
    bucket: k8s-backups
    config:
      resourceGroup: backups-rg
      storageAccount: backupsstorageacct
```

---

## Environment-Specific Configurations

### Development Environment

```yaml
# dev-values.yaml
environment: development

# Lower resource limits
resources:
  prometheus:
    requests:
      cpu: 250m
      memory: 1Gi
    limits:
      cpu: 500m
      memory: 2Gi

# Shorter retention
prometheus:
  retention: 7d
loki:
  retention:
    period: 168h  # 7 days

# Smaller storage
storage:
  prometheus:
    size: 20Gi
  loki:
    size: 30Gi

# Disable HA
highAvailability:
  enabled: false

prometheus:
  replicas: 1
grafana:
  replicas: 1
```

### Staging Environment

```yaml
# staging-values.yaml
environment: staging

# Medium resource limits
resources:
  prometheus:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 1000m
      memory: 4Gi

# Medium retention
prometheus:
  retention: 15d
loki:
  retention:
    period: 360h  # 15 days

# Medium storage
storage:
  prometheus:
    size: 50Gi
  loki:
    size: 75Gi
```

### Production Environment

```yaml
# prod-values.yaml
environment: production

# Full resource limits
resources:
  prometheus:
    requests:
      cpu: 1000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 16Gi

# Long retention
prometheus:
  retention: 30d
loki:
  retention:
    period: 720h  # 30 days

# Large storage
storage:
  prometheus:
    size: 100Gi
  loki:
    size: 200Gi

# Enable HA
highAvailability:
  enabled: true

prometheus:
  replicas: 2
grafana:
  replicas: 2
loki:
  replicas: 3

# Enable backups
backup:
  enabled: true

# Strict security
podSecurityPolicy:
  enabled: true

networkPolicies:
  enabled: true
```

---

## Configuration Best Practices

### 1. Use Secrets for Sensitive Data

```bash
# Create secrets for passwords
kubectl create secret generic grafana-admin \
  --from-literal=admin-password='YourSecurePassword' \
  -n monitoring

# Create secrets for API keys
kubectl create secret generic alertmanager-slack \
  --from-literal=api-url='https://hooks.slack.com/services/YOUR/WEBHOOK' \
  -n monitoring
```

### 2. Version Control Your Values

```bash
# Keep environment-specific values in git
git/
├── values/
│   ├── dev-values.yaml
│   ├── staging-values.yaml
│   └── prod-values.yaml
└── secrets/  # Encrypted with SOPS or sealed-secrets
    ├── dev-secrets.yaml
    ├── staging-secrets.yaml
    └── prod-secrets.yaml
```

### 3. Use ConfigMaps for Complex Configs

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-custom-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
    
    scrape_configs:
      - job_name: 'custom-metrics'
        static_configs:
          - targets: ['localhost:9090']
```

### 4. Implement GitOps

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8s-devops-suite
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2
    targetRevision: main
    path: helm-chart
    helm:
      valueFiles:
        - values.yaml
        - ../values/prod-values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Troubleshooting Configuration Issues

### Validate Helm Values

```bash
# Dry run to check for errors
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --values my-values.yaml \
  --dry-run --debug

# Render templates without installing
helm template k8s-devops-suite ./helm-chart \
  --values my-values.yaml \
  --output-dir ./rendered
```

### Check Applied Configuration

```bash
# Check ConfigMaps
kubectl get cm -n monitoring
kubectl describe cm prometheus-config -n monitoring

# Check Secrets
kubectl get secrets -n monitoring
kubectl describe secret grafana-admin -n monitoring

# View actual pod environment
kubectl exec -it prometheus-0 -n monitoring -- env
```

### Configuration Reload

```bash
# Reload Prometheus configuration
kubectl exec -it prometheus-0 -n monitoring -- \
  curl -X POST http://localhost:9090/-/reload

# Restart specific components
kubectl rollout restart deployment/grafana -n monitoring
kubectl rollout restart statefulset/prometheus -n monitoring
```

---

## Next Steps

- [Deployment Guide](./deployment-guide.md) - Deploy the suite
- [Troubleshooting Guide](./troubleshooting.md) - Resolve issues
