# Security Hardening Guidelines

This document provides best practices for securing Kubernetes clusters and the Madarson IT Kubernetes DevOps Suite v2.0.2. The goal is to help operators deploy with confidence, reduce attack surface, and maintain compliance in production environments.

---

## 1. Access Control & Authentication
- **Enable RBAC**: Use Role-Based Access Control and grant the least privilege required.
- **Use short-lived credentials**: Integrate with OIDC or Azure AD; avoid static kubeconfigs.
- **Audit API access**: Enable audit logging to track all API server requests.

## 2. Network & Workload Isolation
- **Namespaces**: Separate workloads by team or environment.
- **Network Policies**: Default to deny-all, then explicitly allow required traffic.
- **Pod Security Standards**: Enforce `baseline` or `restricted` profiles to prevent privileged containers unless explicitly required.

## 3. Image & Supply Chain Security
- **Scan images**: Use Trivy or equivalent to detect vulnerabilities before deployment.
- **Signed images**: Adopt image signing (e.g., Cosign) to verify provenance.
- **Minimal base images**: Reduce attack surface by using slim or distroless images.
- **Trusted registries**: Pull only from approved registries.

## 4. Runtime Security
- **Falco**: Enable runtime detection of suspicious activity (e.g., unexpected `kubectl` execution).
- **Resource limits**: Define CPU/memory requests and limits to prevent noisy-neighbor DoS.
- **Read-only filesystems**: Run containers with read-only root filesystems and drop unnecessary Linux capabilities.

## 5. Data Protection
- **Encrypt secrets at rest**: Enable etcd encryption for Kubernetes secrets.
- **External secret managers**: Integrate with Azure Key Vault or HashiCorp Vault for sensitive credentials.
- **TLS everywhere**: Ensure all traffic between components is encrypted.

## 6. Monitoring & Logging
- **Centralized logging**: Use Loki + Promtail for log aggregation.
- **Metrics & alerts**: Use Prometheus + Alertmanager for anomaly detection.
- **Security dashboards**: Pre-configured Grafana dashboards provide compliance visibility.

## 7. Cluster & Node Hardening
- **Keep Kubernetes updated**: Apply control plane and node patches promptly.
- **Harden nodes**: Disable unused ports, enforce OS patching, and use minimal OS images.
- **Restrict metadata access**: Block pod access to cloud instance metadata unless required.

## 8. CI/CD & Deployment Security
- **Shift-left security**: Scan Helm charts and manifests for misconfigurations before deployment.
- **Admission control**: Use OPA/Gatekeeper or Kyverno to enforce security policies.
- **Atomic deployments**: Use Helm’s `--atomic` flag, but ensure pods can schedule with right-sized resources.

---

## Marketplace-Specific Recommendations
- **Customer-configurable passwords**: Ensure Grafana and other components never ship with defaults.
- **Explicit storage classes**: Set `storageClassName` (e.g., `managed-premium`) to avoid PVCs stuck in `Pending`.
- **Secure defaults**: Provide resource requests/limits that work on standard AKS node pools.
- **Optional privileged workloads**: Clearly document that Falco requires privileged pods and is disabled by default.

---

## References
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/)
- [CNCF Security Whitepaper](https://github.com/cncf/tag-security)
- [Falco Runtime Security](https://falco.org/)
- [Trivy Vulnerability Scanner](https://aquasecurity.github.io/trivy/)

---

**Note:** Security is an ongoing process. Regularly review cluster posture, update dependencies, and monitor for new vulnerabilities.
