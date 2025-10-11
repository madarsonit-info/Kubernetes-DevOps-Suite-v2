# Customization Guide for Customers

This guide explains the configuration values you should customize for your environment.

## Required Customizations

### 1. Grafana Admin Password

**Location**: `examples/basic-setup/values.yaml` or your custom values file
```yaml
grafana:
  adminPassword: prom-operator  # ⚠️ CHANGE THIS to a strong password!
Action: Replace with a strong password (minimum 12 characters, mixed case, numbers, symbols)
2. AlertManager Email Configuration
Location: examples/basic-setup/values.yaml
yaml# Uncomment and configure with your SMTP details:
receivers:
  - name: 'default'
    email_configs:
      - to: 'your-team@yourcompany.com'          # Your team email
        from: 'alertmanager@yourcompany.com'     # Your sender email
        smarthost: 'smtp.yourcompany.com:587'    # Your SMTP server
        auth_username: 'alertmanager@yourcompany.com'
        auth_password: 'your-app-password'       # Your SMTP password
3. Ingress Hostnames (Optional)
Location: examples/basic-setup/values.yaml or custom values
yamlingress:
  enabled: true
  grafana:
    hosts:
      - host: grafana.yourcompany.com  # Change to your domain
4. Azure Key Vault (Optional)
Location: If using external secrets
yamlvaultUrl: https://your-keyvault.vault.azure.net  # Your Azure Key Vault URL
5. Storage Class
Location: examples/basic-setup/values.yaml
yamlglobal:
  storageClass: default  # Change to: managed-premium, azurefile, etc.
Optional Customizations
Slack Notifications
yamlreceivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
Resource Adjustments
Adjust based on your cluster size:
yamlprometheus:
  resources:
    requests:
      cpu: 500m      # Adjust based on cluster size
      memory: 2Gi    # Adjust based on cluster size
Retention Periods
yamlprometheus:
  retention: 15d  # Adjust based on your needs (7d, 30d, 90d)

loki:
  retention:
    period: 720h  # Adjust based on your needs (168h = 7d, 720h = 30d)
Configuration Template
Copy this to my-values.yaml and customize:
yaml# My Company's K8s DevOps Suite Configuration

global:
  storageClass: managed-premium

grafana:
  adminPassword: "MySecurePassword123!"
  
  smtp:
    enabled: true
    host: "smtp.mycompany.com:587"
    user: "monitoring@mycompany.com"
    password: "my-smtp-password"
    from_address: "grafana@mycompany.com"

alertmanager:
  config:
    receivers:
      - name: 'default'
        email_configs:
          - to: 'devops-team@mycompany.com'
            from: 'alertmanager@mycompany.com'
            smarthost: 'smtp.mycompany.com:587'
            auth_username: 'alertmanager@mycompany.com'
            auth_password: 'my-smtp-password'

ingress:
  enabled: true
  className: nginx
  grafana:
    enabled: true
    hosts:
      - host: grafana.mycompany.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.mycompany.com
Then deploy with:
bashhelm install k8s-devops-suite ./helm-chart \
  --namespace monitoring \
  --create-namespace \
  --values my-values.yaml
Security Best Practices

Never commit passwords to git
Use strong passwords (12+ characters)
Use Azure Key Vault for sensitive values in production
Enable TLS for external access
Change default passwords immediately after deployment

Getting Help

See Configuration Guide for all options
See Deployment Guide for step-by-step instructions
Open an issue if you need help
