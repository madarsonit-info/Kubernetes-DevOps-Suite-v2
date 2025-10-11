#!/bin/bash
# Verification Script for K8s DevOps Suite

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
RELEASE_NAME="k8s-devops-suite"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}K8s DevOps Suite - Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
    exit 1
fi

# Counter for issues
ISSUES=0
WARNINGS=0

# Check Pods
echo -e "${YELLOW}Checking Pods...${NC}"
POD_STATUS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null)

if [ -z "$POD_STATUS" ]; then
    echo -e "${RED}✗ No pods found in namespace $NAMESPACE${NC}"
    ((ISSUES++))
else
    TOTAL_PODS=$(echo "$POD_STATUS" | wc -l)
    RUNNING_PODS=$(echo "$POD_STATUS" | grep -c "Running\|Completed" || true)
    
    echo "Total pods: $TOTAL_PODS"
    echo "Running/Completed: $RUNNING_PODS"
    
    if [ $RUNNING_PODS -eq $TOTAL_PODS ]; then
        echo -e "${GREEN}✓ All pods are running${NC}"
    else
        echo -e "${RED}✗ Some pods are not running${NC}"
        kubectl get pods -n $NAMESPACE | grep -v "Running\|Completed" || true
        ((ISSUES++))
    fi
fi
echo ""

# Check specific components
echo -e "${YELLOW}Checking Components...${NC}"

# Prometheus
if kubectl get pod -n $NAMESPACE -l app=prometheus &> /dev/null; then
    PROM_READY=$(kubectl get pod -n $NAMESPACE -l app=prometheus -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$PROM_READY" = "true" ]; then
        echo -e "${GREEN}✓ Prometheus is ready${NC}"
    else
        echo -e "${RED}✗ Prometheus is not ready${NC}"
        ((ISSUES++))
    fi
else
    echo -e "${RED}✗ Prometheus pod not found${NC}"
    ((ISSUES++))
fi

# Grafana
if kubectl get pod -n $NAMESPACE -l app=grafana &> /dev/null; then
    GRAFANA_READY=$(kubectl get pod -n $NAMESPACE -l app=grafana -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$GRAFANA_READY" = "true" ]; then
        echo -e "${GREEN}✓ Grafana is ready${NC}"
    else
        echo -e "${RED}✗ Grafana is not ready${NC}"
        ((ISSUES++))
    fi
else
    echo -e "${RED}✗ Grafana pod not found${NC}"
    ((ISSUES++))
fi

# Loki
if kubectl get pod -n $NAMESPACE -l app=loki &> /dev/null; then
    LOKI_READY=$(kubectl get pod -n $NAMESPACE -l app=loki -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$LOKI_READY" = "true" ]; then
        echo -e "${GREEN}✓ Loki is ready${NC}"
    else
        echo -e "${RED}✗ Loki is not ready${NC}"
        ((ISSUES++))
    fi
else
    echo -e "${RED}✗ Loki pod not found${NC}"
    ((ISSUES++))
fi

echo ""

# Check Services
echo -e "${YELLOW}Checking Services...${NC}"
SERVICES=("prometheus" "grafana" "loki" "alertmanager")

for service in "${SERVICES[@]}"; do
    if kubectl get svc $service -n $NAMESPACE &> /dev/null; then
        ENDPOINTS=$(kubectl get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
        if [ $ENDPOINTS -gt 0 ]; then
            echo -e "${GREEN}✓ Service '$service' has $ENDPOINTS endpoint(s)${NC}"
        else
            echo -e "${RED}✗ Service '$service' has no endpoints${NC}"
            ((ISSUES++))
        fi
    else
        echo -e "${YELLOW}⚠ Service '$service' not found${NC}"
        ((WARNINGS++))
    fi
done
echo ""

# Check PVCs
echo -e "${YELLOW}Checking Persistent Volume Claims...${NC}"
PVC_STATUS=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null)

if [ -z "$PVC_STATUS" ]; then
    echo -e "${YELLOW}⚠ No PVCs found${NC}"
    ((WARNINGS++))
else
    BOUND_PVCS=$(echo "$PVC_STATUS" | grep -c "Bound" || true)
    TOTAL_PVCS=$(echo "$PVC_STATUS" | wc -l)
    
    if [ $BOUND_PVCS -eq $TOTAL_PVCS ]; then
        echo -e "${GREEN}✓ All PVCs are bound ($BOUND_PVCS/$TOTAL_PVCS)${NC}"
    else
        echo -e "${RED}✗ Some PVCs are not bound ($BOUND_PVCS/$TOTAL_PVCS)${NC}"
        kubectl get pvc -n $NAMESPACE | grep -v "Bound" || true
        ((ISSUES++))
    fi
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}Your K8s DevOps Suite is ready to use.${NC}"
    EXIT_CODE=0
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠ Verification completed with $WARNINGS warning(s)${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}✗ Verification found $ISSUES issue(s) and $WARNINGS warning(s)${NC}"
    EXIT_CODE=1
fi

echo ""
echo "Access Grafana:"
echo "  kubectl port-forward svc/grafana 3000:80 -n $NAMESPACE"
echo ""

exit $EXIT_CODE
