# Security Guide

## Overview

This document provides comprehensive security best practices for securing Kubernetes clusters and the Madarson IT Kubernetes DevOps Suite v2.0.3. The goal is to help operators deploy with confidence, reduce attack surface, and maintain compliance in production environments.

---

## 1. Access Control & Authentication

### RBAC Configuration

- **Enable RBAC**: Use Role-Based Access Control and grant the least privilege required.
- **Use short-lived credentials**: Integrate with OIDC or Azure AD; avoid static kubeconfigs.
- **Audit API access**: Enable audit logging to track all API server requests.

```bash
# Verify RBAC is enabled
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus

# Review service account permissions
kubectl describe clusterrole prometheus
```

### Grafana Security

```yaml
# Strong password requirements
grafana:
  adminPassword: "UseAStrongPasswordHere!"  # CHANGE THIS!

  env:
    GF_SECURITY_ADMIN_PASSWORD__FILE: /etc/secrets/admin-password
    GF_AUTH_ANONYMOUS_ENABLED: "false"
    GF_AUTH_DISABLE_LOGIN_FORM: "false"
    GF_USERS_ALLOW_SIGN_UP: "false"
```

**Important:** Never ship with default passwords. Customer-configurable passwords must be set during deployment.

---

## 2. Network & Workload Isolation

### Namespaces

- Separate workloads by team or environment
- Use dedicated namespace for monitoring: `monitoring`

### Network Policies

- Default to deny-all, then explicitly allow required traffic
- Restrict Prometheus, Grafana, and Loki access

```yaml
# Example: Restrict Prometheus access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-network-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: grafana
    ports:
    - protocol: TCP
      port: 9090
```

### Pod Security Standards

- Enforce baseline or restricted profiles to prevent privileged containers unless explicitly required
- **Note:** Falco requires privileged pods and should be explicitly enabled

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### TLS/SSL for External Access

```yaml
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: monitoring-tls
      hosts:
        - grafana.yourdomain.com
```

---

## 3. Image & Supply Chain Security

### Container Image Security

- **Scan images**: Use Trivy or equivalent to detect vulnerabilities before deployment
- **Signed images**: Adopt image signing (e.g., Cosign) to verify provenance
- **Minimal base images**: Reduce attack surface by using slim or distroless images
- **Trusted registries**: Pull only from approved registries

### Trivy Configuration

```yaml
trivy:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  scanConfig:
    severity: "CRITICAL,HIGH"
    ignoreUnfixed: false
```

### Review Scan Results

```bash
# Check scan results
kubectl logs -n monitoring -l app=trivy --tail=100

# Export results for compliance
kubectl logs -n monitoring trivy-scanner-xxx > scan-results.json
```

---

## 4. Runtime Security

### Falco Runtime Detection

- Enable runtime detection of suspicious activity (e.g., unexpected kubectl execution)
- **Optional privileged workloads**: Clearly document that Falco requires privileged pods and is disabled by default in basic setup
- **Custom rules**: Tailor detection rules to your environment

```yaml
falco:
  enabled: true  # Set to false if privileged pods not allowed

  ebpf:
    enabled: true  # Recommended over kernel module

  customRules:
    enabled: true
```

### Custom Falco Rules for DevOps Suite

```yaml
# Place in helm-chart/rules/devops-security.yaml
- rule: Unauthorized Access to Prometheus Data
  desc: Detect unauthorized access to Prometheus data directory
  condition: >
    open_read and
    fd.name startswith /prometheus and
    not proc.name in (prometheus, promtool)
  output: >
    Unauthorized access to Prometheus data
    (user=%user.name process=%proc.name file=%fd.name)
  priority: WARNING

- rule: Grafana Config Modification
  desc: Detect modifications to Grafana configuration
  condition: >
    open_write and
    fd.name startswith /etc/grafana and
    not proc.name in (grafana, grafana-server)
  output: >
    Grafana configuration modified
    (user=%user.name process=%proc.name file=%fd.name)
  priority: CRITICAL
```

### Resource Limits

- Define CPU/memory requests and limits to prevent noisy-neighbor DoS
- **Read-only filesystems**: Run containers with read-only root filesystems
- Drop unnecessary Linux capabilities

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
    - ALL
```

---

## 5. Data Protection

### Secrets Management

- **Encrypt secrets at rest**: Enable etcd encryption for Kubernetes secrets
- **External secret managers**: Integrate with Azure Key Vault or HashiCorp Vault for sensitive credentials
- **TLS everywhere**: Ensure all traffic between components is encrypted

### Using Kubernetes Secrets

```bash
# Create secret for sensitive data
kubectl create secret generic alertmanager-config \
  --from-literal=slack-webhook='https://hooks.slack.com/...' \
  -n monitoring
```

### External Secrets Operator (Recommended)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: monitoring
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: https://your-keyvault.vault.azure.net
```

---

## 6. Monitoring & Logging

### Centralized Logging

- Use Loki + Promtail for log aggregation
- Configure appropriate retention policies
- Monitor for security-related log patterns

### Metrics & Alerts

- Use Prometheus + Alertmanager for anomaly detection
- Set up alerts for security events
- Monitor component health

### Security Dashboards

- Pre-configured Grafana dashboards provide compliance visibility
- Custom dashboards for Falco events
- Track vulnerability scan results

```bash
# Monitor Falco events in real-time
kubectl logs -f -n monitoring -l app=falco

# Check AlertManager for security alerts
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Visit: http://localhost:9093
```

---

## 7. Cluster & Node Hardening

### Kubernetes Updates

- **Keep Kubernetes updated**: Apply control plane and node patches promptly
- Test updates in non-production first
- Review changelogs for security fixes

### Node Security

- **Harden nodes**: Disable unused ports, enforce OS patching
- **Use minimal OS images**: Azure Linux, Ubuntu minimal, or similar
- **Restrict metadata access**: Block pod access to cloud instance metadata unless required

### AKS-Specific Recommendations

- Enable Azure Policy for AKS
- Use managed identities instead of service principals
- Enable Azure Defender for Kubernetes
- Configure diagnostic settings

---

## 8. CI/CD & Deployment Security

### Shift-Left Security

- Scan Helm charts and manifests for misconfigurations before deployment
- Use tools like `helm lint`, `kubeval`, or `kubesec`
- Integrate security scanning in CI/CD pipelines

### Admission Control

- Use OPA/Gatekeeper or Kyverno to enforce security policies
- Validate resource requests/limits
- Enforce naming conventions and labels

### Deployment Best Practices

- **Atomic deployments**: Use Helm's `--atomic` flag
- Ensure pods can schedule with right-sized resources
- Test in staging before production
- Maintain rollback procedures

```bash
# Deploy with atomic flag
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --values values.yaml \
  --atomic \
  --timeout 10m
```

---

## 9. Azure Marketplace-Specific Recommendations

### Secure Defaults

- **Customer-configurable passwords**: Ensure Grafana and other components never ship with defaults
- **Explicit storage classes**: Set `storageClassName` (e.g., `managed-premium`) to avoid PVCs stuck in Pending
- **Secure defaults**: Provide resource requests/limits that work on standard AKS node pools
- **Optional privileged workloads**: Clearly document that Falco requires privileged pods

### Storage Configuration

```yaml
# Use premium storage for production
global:
  storageClass: managed-premium  # Azure Premium SSD

# Or Azure Files for shared storage
global:
  storageClass: azurefile
```

### Resource Sizing Guidance

```yaml
# Minimum for basic setup (development)
# 3 nodes × Standard_D4s_v3 (4 vCPUs, 16GB RAM)

# Recommended for production
# 5+ nodes × Standard_D8s_v3 (8 vCPUs, 32GB RAM)
```

---

## 10. Compliance & Audit

### CIS Benchmark Alignment

- ✅ Non-root containers
- ✅ Read-only root filesystem (where applicable)
- ✅ No privilege escalation
- ✅ Resource limits defined
- ✅ Network policies available

### GDPR Considerations

- Data retention policies configured
- Access logging enabled
- Encryption at rest available
- Right to deletion supported

### Audit Logging

```yaml
# Enable Kubernetes audit logs for monitoring namespace
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  namespaces: ["monitoring"]
  verbs: ["create", "update", "patch", "delete"]
```

---

## 11. Incident Response

### Security Event Monitoring

1. **Detection**: Falco triggers alert
2. **Analysis**: Review logs and metrics in Grafana
3. **Containment**: Apply network policies
4. **Eradication**: Remove threat
5. **Recovery**: Restore from backup if needed
6. **Lessons Learned**: Update security rules

### Response Procedures

```bash
# 1. Check Falco alerts
kubectl logs -n monitoring -l app=falco --tail=100 | grep CRITICAL

# 2. Review recent events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# 3. Check for compromised pods
kubectl get pods -n monitoring -o wide

# 4. Review access logs
kubectl logs -n kube-system -l component=kube-apiserver
```

---

## Security Checklist

### Pre-Deployment
- [ ] Strong passwords configured (no defaults)
- [ ] Storage class explicitly set
- [ ] Resource requests/limits defined
- [ ] RBAC roles reviewed
- [ ] Network policies prepared (if required)

### Post-Deployment
- [ ] Change default passwords immediately
- [ ] Enable TLS for external access
- [ ] Configure backup schedule
- [ ] Set up alerting channels (email/Slack)
- [ ] Review Falco rules and test alerts
- [ ] Run initial Trivy scan
- [ ] Enable audit logging
- [ ] Document custom configurations

### Ongoing Operations
- [ ] Regular vulnerability scans
- [ ] Monitor security alerts
- [ ] Review access logs monthly
- [ ] Update components quarterly
- [ ] Test backup/recovery procedures 
- [ ] Security training for team
- [ ] Incident response drills

---

## References

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/)
- [CNCF Security Whitepaper](https://github.com/cncf/tag-security)
- [Falco Runtime Security](https://falco.org/)
- [Trivy Vulnerability Scanner](https://aquasecurity.github.io/trivy/)
- [Azure AKS Security Best Practices](https://learn.microsoft.com/en-us/azure/aks/operator-best-practices-cluster-security?tabs=azure-cli)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)

---

**Note:** Security is an ongoing process. Regularly review cluster posture, update dependencies, and monitor for new vulnerabilities. This guide should be reviewed and updated as security practices evolve.

---

For configuration details, see [Configuration Guide](configuration.md).  
For troubleshooting security issues, see [Troubleshooting Guide](troubleshooting.md).
