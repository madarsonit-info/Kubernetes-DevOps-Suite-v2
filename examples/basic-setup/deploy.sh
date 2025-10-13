#!/bin/bash
# Basic Setup Deployment Script for K8s DevOps Suite

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
RELEASE_NAME="k8s-devops-suite"
HELM_CHART_PATH="/home/shola/madarson-k8s-devops-suite/helm-chart"
VALUES_FILE="values.yaml"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}K8s DevOps Suite - Basic Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Not connected to a Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Check if namespace exists
echo -e "${YELLOW}Checking namespace...${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}Namespace '$NAMESPACE' already exists${NC}"
else
    echo -e "${YELLOW}Creating namespace '$NAMESPACE'...${NC}"
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓ Namespace created${NC}"
fi
echo ""

# Check if helm chart exists
if [ ! -d "$HELM_CHART_PATH" ]; then
    echo -e "${RED}Error: Helm chart not found at $HELM_CHART_PATH${NC}"
    exit 1
fi

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}Error: Values file not found: $VALUES_FILE${NC}"
    exit 1
fi

# Validate helm chart
echo -e "${YELLOW}Validating Helm chart...${NC}"
if helm lint $HELM_CHART_PATH --values $VALUES_FILE; then
    echo -e "${GREEN}✓ Helm chart validation passed${NC}"
else
    echo -e "${RED}Error: Helm chart validation failed${NC}"
    exit 1
fi
echo ""

# Check cluster resources
echo -e "${YELLOW}Checking cluster resources...${NC}"
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "Nodes available: $NODE_COUNT"

if [ $NODE_COUNT -lt 3 ]; then
    echo -e "${YELLOW}Warning: Less than 3 nodes available. Deployment may have issues.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Check if release already exists
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    echo -e "${YELLOW}Release '$RELEASE_NAME' already exists${NC}"
    read -p "Do you want to upgrade? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Upgrading release...${NC}"
        helm upgrade $RELEASE_NAME $HELM_CHART_PATH \
            --namespace $NAMESPACE \
            --values $VALUES_FILE \
            --wait \
            --timeout 10m
        echo -e "${GREEN}✓ Upgrade completed${NC}"
    else
        echo -e "${YELLOW}Skipping deployment${NC}"
        exit 0
    fi
else
    # Deploy with Helm
    echo -e "${YELLOW}Deploying K8s DevOps Suite...${NC}"
    helm install $RELEASE_NAME $HELM_CHART_PATH \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout 10m
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Deployment completed successfully${NC}"
    else
        echo -e "${RED}Error: Deployment failed${NC}"
        exit 1
    fi
fi
echo ""

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
echo "This may take a few minutes..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/instance=$RELEASE_NAME \
    -n $NAMESPACE \
    --timeout=5m || true

echo ""

# Display deployment status
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo "Pods:"
kubectl get pods -n $NAMESPACE

echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE

echo ""
echo "Persistent Volume Claims:"
kubectl get pvc -n $NAMESPACE

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Access Information${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get Grafana password
GRAFANA_PASSWORD=$(kubectl get secret grafana -n $NAMESPACE -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d)
if [ -z "$GRAFANA_PASSWORD" ]; then
    GRAFANA_PASSWORD="prom-operator"  # Default from values
fi

echo -e "${YELLOW}Grafana:${NC}"
echo "  Port Forward: kubectl port-forward svc/grafana 3000:80 -n $NAMESPACE"
echo "  URL: http://localhost:3000"
echo "  Username: admin"
echo "  Password: $GRAFANA_PASSWORD"
echo ""

echo -e "${YELLOW}Prometheus:${NC}"
echo "  Port Forward: kubectl port-forward svc/prometheus 9090:9090 -n $NAMESPACE"
echo "  URL: http://localhost:9090"
echo ""

echo -e "${YELLOW}AlertManager:${NC}"
echo "  Port Forward: kubectl port-forward svc/alertmanager 9093:9093 -n $NAMESPACE"
echo "  URL: http://localhost:9093"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Run verification script: ./verify.sh"
echo "2. Access Grafana and explore pre-configured dashboards"
echo "3. Review logs: kubectl logs -n $NAMESPACE -l app=prometheus"
echo "4. Check documentation: ../../docs/"
echo ""

echo -e "${GREEN}Deployment completed successfully!${NC}"
