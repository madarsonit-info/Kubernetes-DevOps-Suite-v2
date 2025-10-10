# Troubleshooting Guide

## Table of Contents
- [General Troubleshooting Steps](#general-troubleshooting-steps)
- [Pod Issues](#pod-issues)
- [Storage Issues](#storage-issues)
- [Prometheus Issues](#prometheus-issues)
- [Grafana Issues](#grafana-issues)
- [Loki & Promtail Issues](#loki--promtail-issues)
- [Falco Issues](#falco-issues)
- [Networking Issues](#networking-issues)
- [Performance Issues](#performance-issues)
- [Data Collection Issues](#data-collection-issues)

---

## General Troubleshooting Steps

### Quick Health Check

```bash
# Check all pods status
kubectl get pods -n monitoring

# Check recent events
kubectl get events -n monitoring --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top nodes
kubectl top pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring
```

### Get Detailed Information

```bash
# Describe a problematic pod
kubectl describe pod <pod-name> -n monitoring

# View pod logs
kubectl logs <pod-name> -n monitoring

# View previous container logs (if crashed)
kubectl logs <pod-name> -n monitoring --previous

# Follow logs in real-time
kubectl logs -f <pod-name> -n monitoring

# Check all container logs in a pod
kubectl logs <pod-name> -n monitoring --all-containers=true
```

### Export Debug Information

```bash
# Create debug bundle
mkdir debug-bundle
kubectl get all -n monitoring -o yaml > debug-bundle/all-resources.yaml
kubectl describe pods -n monitoring > debug-bundle/pod-descriptions.txt
kubectl logs -n monitoring --all-containers=true --prefix=true > debug-bundle/all-logs.txt
kubectl get events -n monitoring > debug-bundle/events.txt
kubectl top nodes > debug-bundle/node-resources.txt
kubectl top pods -n monitoring > debug-bundle/pod-resources.txt

# Create tarball
tar -czf debug-bundle-$(date +%Y%m%d-%H%M%S).tar.gz debug-bundle/
```

---

## Pod Issues

### Pod Stuck in Pending State

**Symptoms:**
- Pod shows `Pending` status
- Pod never starts

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n monitoring
```

**Common Causes & Solutions:**

#### 1. Insufficient Resources

```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check pod resource requests
kubectl get pod <pod-name> -n monitoring -o yaml | grep -A 10 resources
```

**Solution:**
- Scale up cluster or add nodes
- Reduce resource requests in values.yaml
- Remove resource limits temporarily

```yaml
# Reduce in values.yaml
prometheus:
  resources:
    requests:
      cpu: 250m  # Reduced from 500m
      memory: 1Gi  # Reduced from 2Gi
```

#### 2. PVC Not Bound

```bash
# Check PVC status
kubectl get pvc -n monitoring
```

**Solution:**
```bash
# Check storage class exists
kubectl get storageclass

# Check PVC events
kubectl describe pvc <pvc-name> -n monitoring

# If using Azure, ensure storage class is available
kubectl get storageclass | grep azure
```

#### 3. Node Selector Mismatch

```bash
# Check pod node selector
kubectl get pod <pod-name> -n monitoring -o yaml | grep -A 5 nodeSelector

# Check node labels
kubectl get nodes --show-labels
```

**Solution:**
- Remove node selector from values.yaml
- Or add required labels to nodes:
```bash
kubectl label node <node-name> workload-type=monitoring
```

### Pod CrashLoopBackOff

**Symptoms:**
- Pod shows `CrashLoopBackOff` status
- Restart count keeps increasing

**Diagnosis:**
```bash
# Check logs from previous run
kubectl logs <pod-name> -n monitoring --previous

# Check container exit code
kubectl describe pod <pod-name> -n monitoring | grep -A 5 "Last State"
```

**Common Causes & Solutions:**

#### 1. Configuration Error

```bash
# Check ConfigMaps
kubectl get cm -n monitoring
kubectl describe cm <config-name> -n monitoring

# Validate configuration syntax
kubectl exec -it <pod-name> -n monitoring -- cat /etc/config/file.yaml
```

**Solution:**
- Fix configuration in ConfigMap
- Restart pod:
```bash
kubectl delete pod <pod-name> -n monitoring
```

#### 2. Missing Dependencies

```bash
# Check if dependent services are running
kubectl get pods -n monitoring | grep -E "prometheus|loki|grafana"
```

**Solution:**
- Wait for dependencies to be ready
- Check service endpoints:
```bash
kubectl get endpoints -n monitoring
```

#### 3. Insufficient Memory

```bash
# Check OOMKilled status
kubectl describe pod <pod-name> -n monitoring | grep OOMKilled
```

**Solution:**
```yaml
# Increase memory limits in values.yaml
resources:
  limits:
    memory: 4Gi  # Increased from 2Gi
```

### Pod in ImagePullBackOff

**Symptoms:**
- Pod shows `ImagePullBackOff` or `ErrImagePull`
- Cannot pull container image

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n monitoring | grep -A 10 Events
```

**Solutions:**

```bash
# 1. Check image name and tag
kubectl get pod <pod-name> -n monitoring -o yaml | grep image:

# 2. Check if image exists
docker pull <image-name>:<tag>

# 3. Check image pull secrets (if using private registry)
kubectl get secrets -n monitoring

# 4. Create image pull secret if needed
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n monitoring
```

---

## Storage Issues

### PVC Not Binding

**Symptoms:**
- PVC shows `Pending` status
- No volume is created

**Diagnosis:**
```bash
kubectl describe pvc <pvc-name> -n monitoring
kubectl get storageclass
```

**Solutions:**

```bash
# 1. Check storage class exists and is default
kubectl get storageclass
kubectl describe storageclass <storage-class-name>

# 2. Create storage class if missing (Azure example)
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
EOF

# 3. Check Azure subscription quota
az vm list-usage --location eastus --output table | grep "Total Regional vCPUs"
```

### Disk Full Errors

**Symptoms:**
- Pods showing disk pressure
- Write errors in logs
- Prometheus remote write failing

**Diagnosis:**
```bash
# Check PVC usage
kubectl exec -it <pod-name> -n monitoring -- df -h

# Check disk usage per component
kubectl exec -it prometheus-0 -n monitoring -- du -sh /prometheus
kubectl exec -it loki-0 -n monitoring -- du -sh /data
```

**Solutions:**

```bash
# 1. Expand PVC (if storage class supports it)
kubectl patch pvc <pvc-name> -n monitoring -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# 2. Clean up old data manually
kubectl exec -it prometheus-0 -n monitoring -- sh
# Inside pod:
cd /prometheus
rm -rf old-data-blocks/

# 3. Reduce retention period
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set prometheus.retention=7d \
  --reuse-values
```

### PVC Stuck in Terminating

**Symptoms:**
- PVC won't delete
- Stuck in `Terminating` state

**Diagnosis:**
```bash
kubectl describe pvc <pvc-name> -n monitoring
kubectl get pvc <pvc-name> -n monitoring -o yaml | grep finalizers
```

**Solutions:**

```bash
# 1. Check if pod using PVC is deleted
kubectl get pods -n monitoring | grep <pod-name>

# 2. Force delete pod if still running
kubectl delete pod <pod-name> -n monitoring --force --grace-period=0

# 3. Remove finalizers from PVC
kubectl patch pvc <pvc-name> -n monitoring -p '{"metadata":{"finalizers":null}}'

# 4. As last resort, edit and remove finalizers
kubectl edit pvc <pvc-name> -n monitoring
# Remove the finalizers section and save
```

---

## Prometheus Issues

### Prometheus Not Scraping Targets

**Symptoms:**
- Targets showing as down in Prometheus UI
- No metrics being collected

**Diagnosis:**
```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Check targets in browser: http://localhost:9090/targets
# Check service discovery: http://localhost:9090/service-discovery
```

**Solutions:**

#### 1. Check ServiceMonitor

```bash
# List service monitors
kubectl get servicemonitor -n monitoring

# Describe service monitor
kubectl describe servicemonitor <name> -n monitoring

# Check if labels match services
kubectl get svc -n monitoring --show-labels
```

#### 2. Check RBAC Permissions

```bash
# Check ClusterRole
kubectl get clusterrole | grep prometheus
kubectl describe clusterrole prometheus

# Check ClusterRoleBinding
kubectl get clusterrolebinding | grep prometheus
```

**Fix RBAC:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - nodes/metrics
      - services
      - endpoints
      - pods
    verbs: ["get", "list", "watch"]
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs: ["get", "list", "watch"]
```

#### 3. Network Connectivity

```bash
# Test connectivity from Prometheus pod
kubectl exec -it prometheus-0 -n monitoring -- sh
wget -O- http://<target-service>:<port>/metrics
```

### Prometheus High Memory Usage

**Symptoms:**
- Prometheus pod OOMKilled
- High memory consumption
- Slow query performance

**Diagnosis:**
```bash
# Check memory usage
kubectl top pod prometheus-0 -n monitoring

# Check Prometheus metrics about itself
# In Prometheus UI: process_resident_memory_bytes
```

**Solutions:**

```bash
# 1. Reduce retention
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set prometheus.retention=7d \
  --set prometheus.retentionSize=40GB \
  --reuse-values

# 2. Increase memory limits
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set prometheus.resources.limits.memory=16Gi \
  --reuse-values

# 3. Reduce scrape frequency
kubectl edit cm prometheus-config -n monitoring
# Change scrape_interval from 30s to 60s

# 4. Remove high-cardinality metrics
# Add to prometheus.yml:
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'high_cardinality_metric_.*'
    action: drop
```

### Prometheus Queries Timing Out

**Symptoms:**
- Queries fail with timeout
- Dashboard panels not loading

**Solutions:**
```bash
# 1. Check query complexity
# In Prometheus UI, try simpler queries first

# 2. Increase query timeout
kubectl edit deployment prometheus -n monitoring
# Add: --query.timeout=2m

# 3. Add query limits
# In prometheus.yml:
global:
  query_log_file: /prometheus/queries.log
  
# Check slow queries
kubectl exec -it prometheus-0 -n monitoring -- cat /prometheus/queries.log | grep -A 5 "duration"
```

---

## Grafana Issues

### Cannot Access Grafana Dashboard

**Symptoms:**
- Cannot reach Grafana UI
- Connection refused or timeout

**Diagnosis:**
```bash
# Check Grafana pod
kubectl get pod -n monitoring | grep grafana
kubectl logs -n monitoring <grafana-pod>

# Check service
kubectl get svc grafana -n monitoring
kubectl describe svc grafana -n monitoring
```

**Solutions:**

```bash
# 1. Port forward directly to pod
kubectl port-forward -n monitoring <grafana-pod> 3000:3000

# 2. Check if LoadBalancer is assigned (if using LoadBalancer)
kubectl get svc grafana -n monitoring -o yaml | grep loadBalancer

# 3. Create NodePort service temporarily
kubectl expose deployment grafana --type=NodePort --name=grafana-nodeport -n monitoring
kubectl get svc grafana-nodeport -n monitoring
```

### Grafana Datasource Not Working

**Symptoms:**
- Datasource shows red/disconnected
- Dashboards show "No data"

**Diagnosis:**
```bash
# Check datasource configuration
kubectl exec -it <grafana-pod> -n monitoring -- cat /etc/grafana/provisioning/datasources/datasource.yaml

# Test connectivity from Grafana pod
kubectl exec -it <grafana-pod> -n monitoring -- sh
wget -O- http://prometheus:9090/api/v1/query?query=up
wget -O- http://loki:3100/ready
```

**Solutions:**

```bash
# 1. Verify service names and ports
kubectl get svc -n monitoring

# 2. Update datasource ConfigMap
kubectl edit cm grafana-datasources -n monitoring

# Ensure correct URLs:
# Prometheus: http://prometheus:9090
# Loki: http://loki:3100

# 3. Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

### Forgot Grafana Admin Password

**Solutions:**

```bash
# 1. Check secret
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
echo

# 2. Reset password using grafana-cli
kubectl exec -it <grafana-pod> -n monitoring -- grafana-cli admin reset-admin-password newpassword

# 3. Update secret
kubectl create secret generic grafana \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=newpassword \
  --dry-run=client -o yaml | kubectl apply -n monitoring -f -

kubectl rollout restart deployment/grafana -n monitoring
```

### Dashboards Not Loading

**Symptoms:**
- Dashboard shows "Panel plugin not found"
- Empty dashboards

**Solutions:**

```bash
# 1. Check dashboard ConfigMaps
kubectl get cm -n monitoring | grep dashboard

# 2. Check Grafana plugins
kubectl exec -it <grafana-pod> -n monitoring -- grafana-cli plugins ls

# 3. Reinstall dashboards
kubectl delete cm grafana-dashboards -n monitoring
helm upgrade k8s-devops-suite ./helm-chart --namespace monitoring --reuse-values

# 4. Check dashboard JSON format
kubectl get cm <dashboard-cm> -n monitoring -o yaml
# Ensure proper JSON structure
```

---

## Loki & Promtail Issues

### Promtail Not Sending Logs

**Symptoms:**
- No logs appearing in Grafana Loki datasource
- Promtail pods running but no data

**Diagnosis:**
```bash
# Check Promtail logs
kubectl logs -n monitoring <promtail-pod> | grep error

# Check Promtail targets
kubectl port-forward -n monitoring <promtail-pod> 3101:3101
# Visit: http://localhost:3101/targets
```

**Solutions:**

```bash
# 1. Verify Loki endpoint
kubectl exec -it <promtail-pod> -n monitoring -- sh
wget -O- http://loki:3100/ready

# 2. Check Promtail configuration
kubectl get cm promtail-config -n monitoring -o yaml

# 3. Verify log file paths
kubectl exec -it <promtail-pod> -n monitoring -- ls -la /var/log/pods/

# 4. Check RBAC permissions
kubectl describe clusterrole promtail
# Promtail needs permissions to list pods and read logs

# 5. Restart Promtail DaemonSet
kubectl rollout restart daemonset/promtail -n monitoring
```

### Loki Out of Memory

**Symptoms:**
- Loki pod OOMKilled
- High memory usage

**Solutions:**

```bash
# 1. Reduce ingestion rate
kubectl edit cm loki-config -n monitoring
# Add/modify:
limits_config:
  ingestion_rate_mb: 4  # Reduce from default
  ingestion_burst_size_mb: 6

# 2. Increase memory limits
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set loki.resources.limits.memory=4Gi \
  --reuse-values

# 3. Reduce retention
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set loki.retention.period=336h \
  --reuse-values  # 14 days instead of 30

# 4. Enable compression
kubectl edit cm loki-config -n monitoring
# Add:
chunk_encoding: snappy
```

### Cannot Query Logs in Grafana

**Symptoms:**
- Loki datasource connected but queries fail
- "No logs found" or timeout errors

**Solutions:**

```bash
# 1. Test Loki directly
kubectl port-forward svc/loki 3100:3100 -n monitoring
curl -G -s  "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={namespace="monitoring"}' | jq

# 2. Check query syntax
# Use correct LogQL: {namespace="monitoring"} |= "error"

# 3. Check time range
# Ensure selected time range contains data

# 4. Check Loki ingester
kubectl logs -n monitoring <loki-pod> | grep ingester

# 5. Flush chunks
kubectl exec -it <loki-pod> -n monitoring -- wget -O- http://localhost:3100/flush
```

---

## Falco Issues

### Falco Not Starting

**Symptoms:**
- Falco pods in CrashLoopBackOff
- Errors about kernel module

**Diagnosis:**
```bash
kubectl logs -n monitoring <falco-pod>
```

**Solutions:**

```bash
# 1. Check kernel headers (Falco needs them)
kubectl exec -it <falco-pod> -n monitoring -- ls -la /host/usr/src/kernels/

# 2. Use eBPF probe instead of kernel module
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set falco.ebpf.enabled=true \
  --reuse-values

# 3. Check privileged mode is enabled
kubectl get pod <falco-pod> -n monitoring -o yaml | grep privileged
# Should be true

# 4. Verify host path mounts
kubectl get pod <falco-pod> -n monitoring -o yaml | grep -A 5 hostPath
```

### Falco Not Detecting Events

**Symptoms:**
- Falco running but no alerts
- Falcosidekick not receiving events

**Solutions:**

```bash
# 1. Check Falco rules are loaded
kubectl exec -it <falco-pod> -n monitoring -- falco --list

# 2. Test with a trigger event
kubectl run test-shell --rm -it --image=alpine --restart=Never -- sh
# Inside container, run: cat /etc/shadow
# This should trigger an alert

# 3. Check Falco output
kubectl logs -n monitoring <falco-pod> --tail=100

# 4. Verify Falcosidekick connection
kubectl logs -n monitoring <falcosidekick-pod>

# 5. Check rules configuration
kubectl get cm falco-rules -n monitoring -o yaml
```

---

## Networking Issues

### Services Not Accessible

**Diagnosis:**
```bash
# Check services
kubectl get svc -n monitoring

# Check endpoints
kubectl get endpoints -n monitoring

# Test DNS resolution
kubectl run test-dns --rm -it --image=busybox --restart=Never -- nslookup prometheus.monitoring.svc.cluster.local

# Test connectivity
kubectl run test-curl --rm -it --image=curlimages/curl --restart=Never -- \
  curl -v http://prometheus.monitoring.svc.cluster.local:9090/-/healthy
```

**Solutions:**

```bash
# 1. Check NetworkPolicies
kubectl get networkpolicy -n monitoring
kubectl describe networkpolicy <policy-name> -n monitoring

# 2. Temporarily allow all traffic for testing
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-temp
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
EOF

# 3. Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system <coredns-pod>

# 4. Verify service selectors match pod labels
kubectl get svc prometheus -n monitoring -o yaml | grep selector
kubectl get pod -n monitoring --show-labels | grep prometheus
```

### Ingress Not Working

**Symptoms:**
- Cannot access services through ingress
- 404 or 502 errors

**Solutions:**

```bash
# 1. Check ingress controller is running
kubectl get pods -n ingress-nginx  # or your ingress namespace
kubectl logs -n ingress-nginx <ingress-controller-pod>

# 2. Check ingress resource
kubectl get ingress -n monitoring
kubectl describe ingress <ingress-name> -n monitoring

# 3. Verify backend service exists
kubectl get svc grafana -n monitoring

# 4. Check ingress events
kubectl get events -n monitoring | grep ingress

# 5. Test backend directly
kubectl port-forward svc/grafana 3000:80 -n monitoring

# 6. Check TLS certificate (if using HTTPS)
kubectl get certificate -n monitoring
kubectl describe certificate <cert-name> -n monitoring
```

---

## Performance Issues

### High CPU Usage

**Symptoms:**
- Nodes showing high CPU
- Pods being throttled

**Diagnosis:**
```bash
# Check top consumers
kubectl top nodes
kubectl top pods -n monitoring --sort-by=cpu

# Check specific pod CPU
kubectl exec -it <pod-name> -n monitoring -- top
```

**Solutions:**

```bash
# 1. Increase CPU limits
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set prometheus.resources.limits.cpu=4000m \
  --reuse-values

# 2. Reduce scrape frequency
kubectl edit cm prometheus-config -n monitoring
# Increase scrape_interval from 30s to 60s

# 3. Disable expensive metrics
# In prometheus.yml, add:
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'expensive_metric_.*'
    action: drop

# 4. Scale horizontally (if supported)
kubectl scale deployment grafana --replicas=2 -n monitoring
```

### Slow Query Performance

**Symptoms:**
- Dashboard panels timing out
- Slow Prometheus queries

**Solutions:**

```bash
# 1. Use recording rules for complex queries
# Create recording-rules.yaml:
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-recording-rules
  namespace: monitoring
data:
  recording_rules.yaml: |
    groups:
      - name: aggregate_metrics
        interval: 30s
        rules:
          - record: node_cpu_usage:avg
            expr: avg(rate(node_cpu_seconds_total[5m])) by (instance)
          - record: pod_memory_usage:sum
            expr: sum(container_memory_usage_bytes) by (namespace, pod)

# Apply and reload Prometheus
kubectl apply -f recording-rules.yaml
kubectl exec -it prometheus-0 -n monitoring -- curl -X POST http://localhost:9090/-/reload

# 2. Add indexes to Loki
kubectl edit cm loki-config -n monitoring
# Optimize schema_config

# 3. Use query caching
# In grafana datasource settings, enable caching

# 4. Optimize dashboard queries
# Use $__rate_interval instead of fixed intervals
# Use recording rules for complex aggregations
```

### Disk I/O Issues

**Symptoms:**
- Slow write performance
- Disk latency warnings

**Solutions:**

```bash
# 1. Use premium storage class (Azure)
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set global.storageClass=managed-premium \
  --reuse-values

# 2. Increase IOPS (if using cloud provider)
# For Azure, change storage tier

# 3. Reduce write operations
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set prometheus.scrapeInterval=60s \
  --reuse-values

# 4. Enable WAL compression (Prometheus)
kubectl edit statefulset prometheus -n monitoring
# Add: --storage.tsdb.wal-compression
```

---

## Data Collection Issues

### Missing Metrics

**Symptoms:**
- Some metrics not appearing in Prometheus
- Dashboard panels showing no data

**Diagnosis:**
```bash
# Check if target is up
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit: http://localhost:9090/targets

# Check metric is being scraped
# In Prometheus UI, query: up{job="<job-name>"}

# Check service monitor
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor <name> -n monitoring
```

**Solutions:**

```bash
# 1. Verify service has correct labels
kubectl get svc <service-name> -n monitoring --show-labels

# 2. Check service has metrics endpoint
kubectl exec -it <pod-name> -n monitoring -- wget -O- http://localhost:<port>/metrics

# 3. Add service monitor manually
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: custom-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: custom-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF

# 4. Check Prometheus logs for scrape errors
kubectl logs prometheus-0 -n monitoring | grep -i error
```

### Logs Not Appearing

**Symptoms:**
- Logs missing from Loki
- Empty query results in Grafana

**Solutions:**

```bash
# 1. Check Promtail is running on all nodes
kubectl get pods -n monitoring -o wide | grep promtail

# 2. Verify log paths are correct
kubectl exec -it <promtail-pod> -n monitoring -- ls -la /var/log/pods/

# 3. Check Promtail configuration
kubectl get cm promtail-config -n monitoring -o yaml

# 4. Manually test log ingestion
kubectl exec -it <promtail-pod> -n monitoring -- sh
echo "test log entry" >> /var/log/test.log

# 5. Check Loki ingester
kubectl logs <loki-pod> -n monitoring | grep ingester

# 6. Verify namespace/pod labels
kubectl get pods -n monitoring --show-labels
# Promtail uses labels for log metadata
```

### Alert Not Firing

**Symptoms:**
- Expected alerts not triggering
- AlertManager not receiving alerts

**Solutions:**

```bash
# 1. Check alert rules in Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit: http://localhost:9090/alerts

# 2. Test alert expression
# In Prometheus UI, run the alert query manually

# 3. Check AlertManager configuration
kubectl get cm alertmanager-config -n monitoring -o yaml

# 4. Verify AlertManager is receiving alerts
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
# Visit: http://localhost:9093/#/alerts

# 5. Check AlertManager logs
kubectl logs <alertmanager-pod> -n monitoring

# 6. Test alert routing
# Send test alert:
curl -X POST http://localhost:9093/api/v1/alerts -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "critical"
  },
  "annotations": {
    "summary": "Test alert"
  }
}]'
```

---

## Common Error Messages

### "too many open files"

**Error:**
```
Error: too many open files
```

**Solution:**
```bash
# Increase file descriptor limits
kubectl edit deployment <deployment-name> -n monitoring

# Add to container spec:
securityContext:
  sysctls:
  - name: fs.inotify.max_user_instances
    value: "512"
  - name: fs.inotify.max_user_watches
    value: "524288"

# Or set at node level:
# SSH to node and add to /etc/sysctl.conf:
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
sysctl -p
```

### "context deadline exceeded"

**Error:**
```
Error: context deadline exceeded
```

**Solution:**
```bash
# Increase timeout values
kubectl edit deployment <deployment-name> -n monitoring

# For Prometheus queries:
# Add: --query.timeout=2m

# For Loki:
kubectl edit cm loki-config -n monitoring
# Add:
query_timeout: 5m
```

### "no space left on device"

**Error:**
```
Error: no space left on device
```

**Solution:**
```bash
# 1. Check disk usage
kubectl exec -it <pod-name> -n monitoring -- df -h

# 2. Expand PVC
kubectl patch pvc <pvc-name> -n monitoring -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'

# 3. Clean up old data
kubectl exec -it prometheus-0 -n monitoring -- sh
cd /prometheus
# Delete old blocks manually

# 4. Reduce retention
helm upgrade k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --set prometheus.retention=7d \
  --reuse-values
```

### "pod has unbound immediate PersistentVolumeClaims"

**Error:**
```
Warning: pod has unbound immediate PersistentVolumeClaims
```

**Solution:**
```bash
# 1. Check PVC status
kubectl get pvc -n monitoring

# 2. Check storage class
kubectl get storageclass

# 3. Create storage class if missing
# See Storage Issues section above

# 4. Check Azure subscription quotas
az vm list-usage --location <region> --output table

# 5. Manually create PV (if using local storage)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data/prometheus
EOF
```

---

## Recovery Procedures

### Full Cluster Recovery

```bash
# 1. Export current configuration
mkdir backup-$(date +%Y%m%d)
kubectl get all -n monitoring -o yaml > backup-$(date +%Y%m%d)/all-resources.yaml
kubectl get cm -n monitoring -o yaml > backup-$(date +%Y%m%d)/configmaps.yaml
kubectl get secrets -n monitoring -o yaml > backup-$(date +%Y%m%d)/secrets.yaml
kubectl get pvc -n monitoring -o yaml > backup-$(date +%Y%m%d)/pvcs.yaml

# 2. Backup Prometheus data (if possible)
kubectl exec -it prometheus-0 -n monitoring -- tar -czf /tmp/prometheus-backup.tar.gz /prometheus
kubectl cp monitoring/prometheus-0:/tmp/prometheus-backup.tar.gz ./prometheus-backup.tar.gz

# 3. Backup Grafana dashboards
kubectl exec -it <grafana-pod> -n monitoring -- tar -czf /tmp/grafana-backup.tar.gz /var/lib/grafana
kubectl cp monitoring/<grafana-pod>:/tmp/grafana-backup.tar.gz ./grafana-backup.tar.gz

# 4. Reinstall from scratch
helm uninstall k8s-devops-suite -n monitoring
kubectl delete namespace monitoring
kubectl create namespace monitoring

# 5. Restore from backup
kubectl apply -f backup-$(date +%Y%m%d)/secrets.yaml
helm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --values custom-values.yaml

# 6. Restore data (if needed)
kubectl cp ./prometheus-backup.tar.gz monitoring/prometheus-0:/tmp/
kubectl exec -it prometheus-0 -n monitoring -- tar -xzf /tmp/prometheus-backup.tar.gz -C /
```

### Reset Single Component

```bash
# Reset Prometheus
kubectl delete statefulset prometheus -n monitoring
kubectl delete pvc -l app=prometheus -n monitoring
helm upgrade k8s-devops-suite ./helm-chart --namespace monitoring --reuse-values

# Reset Grafana
kubectl delete deployment grafana -n monitoring
kubectl delete pvc grafana -n monitoring
helm upgrade k8s-devops-suite ./helm-chart --namespace monitoring --reuse-values

# Reset Loki
kubectl delete statefulset loki -n monitoring
kubectl delete pvc -l app=loki -n monitoring
helm upgrade k8s-devops-suite ./helm-chart --namespace monitoring --reuse-values
```

---

## Getting Help

### Collect Debug Information

```bash
# Run comprehensive debug collection
./scripts/collect-debug-info.sh

# Or manually:
kubectl cluster-info dump --namespaces monitoring --output-directory=cluster-dump

# Share anonymized logs
kubectl logs -n monitoring --all-containers=true --prefix=true | \
  sed 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/XXX.XXX.XXX.XXX/g' \
  > anonymized-logs.txt
```

### Report Issues

When reporting issues, include:

1. **Environment details:**
```bash
kubectl version
helm version
az aks show --resource-group <rg> --name <cluster> --query kubernetesVersion
```

2. **Component versions:**
```bash
helm list -n monitoring
kubectl get pods -n monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

3. **Resource status:**
```bash
kubectl get all -n monitoring
kubectl get pvc -n monitoring
kubectl top nodes
kubectl top pods -n monitoring
```

4. **Recent events:**
```bash
kubectl get events -n monitoring --sort-by='.lastTimestamp' | tail -50
```

5. **Relevant logs:**
```bash
kubectl logs -n monitoring <pod-name> --tail=200
```

### Support Channels

- **GitHub Issues**: [Report Bug](https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2/issues/new)
- **Azure Marketplace Support**: [Contact Support](https://portal.azure.com/#create/madarsonitllc1614702968211.madarson-k8s-devops-suite-2-0-0madarson-k8s-devops-suite-2-0-0)
- **Documentation**: [View Docs](https://github.com/madarsonit-info/Kubernetes-DevOps-Suite-v2/tree/main/docs)

---

## Preventive Measures

### Monitoring Your Monitoring

```bash
# 1. Set up alerts for the monitoring stack itself
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-stack-alerts
  namespace: monitoring
data:
  alerts.yaml: |
    groups:
      - name: monitoring_stack
        rules:
          - alert: PrometheusDown
            expr: up{job="prometheus"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Prometheus is down"
          
          - alert: GrafanaDown
            expr: up{job="grafana"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Grafana is down"
          
          - alert: PrometheusDiskFull
            expr: (node_filesystem_avail_bytes{mountpoint="/prometheus"} / node_filesystem_size_bytes{mountpoint="/prometheus"}) < 0.1
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Prometheus disk usage > 90%"
EOF

# 2. Regular health checks
# Add to cron or CI/CD:
kubectl get pods -n monitoring | grep -v Running && echo "Some pods are not running!"

# 3. Automated backups
# See Configuration Guide for backup setup
```

### Best Practices

1. **Regular updates**: Keep components updated
```bash
# Check for updates monthly
helm repo update
helm search repo k8s-devops-suite
```

2. **Resource monitoring**: Watch resource usage trends
3. **Capacity planning**: Scale before hitting limits
4. **Documentation**: Keep runbooks updated
5. **Testing**: Test recovery procedures regularly

---

## Next Steps

- [Deployment Guide](./deployment-guide.md) - Deploy the suite
- [Configuration Guide](./configuration.md) - Customize your setup

---

