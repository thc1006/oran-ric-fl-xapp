#!/bin/bash
# FL xApp Deployment Script
# Supports CPU, GPU, and auto-detection deployment

set -e

# Configuration
NAMESPACE="${NAMESPACE:-ricxapp}"
VARIANT="${VARIANT:-auto}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [VARIANT]

Deploy FL xApp to Kubernetes

VARIANT:
  cpu       Deploy CPU version
  gpu       Deploy GPU version
  auto      Auto-detect GPU and deploy appropriate version (default)

OPTIONS:
  -n, --namespace NAMESPACE  Kubernetes namespace (default: ricxapp)
  -w, --wait                 Wait for deployment to be ready
  -h, --help                 Show this help

Examples:
  $0                         # Auto-detect and deploy
  $0 cpu                     # Force CPU deployment
  $0 gpu --wait              # Deploy GPU and wait for ready

EOF
    exit 0
}

# Parse arguments
WAIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        cpu|gpu|auto)
            VARIANT="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Change to project root
cd "$(dirname "$0")/.."

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed"
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
fi

info "Deployment configuration:"
info "  Namespace: $NAMESPACE"
info "  Variant: $VARIANT"

# GPU detection function
detect_gpu() {
    step "Detecting GPU availability..."

    local gpu_count=$(kubectl get nodes -o json 2>/dev/null | \
        jq -r '.items[].status.capacity."nvidia.com/gpu" // "0"' | \
        awk '{sum += $1} END {print sum}')

    if [ -z "$gpu_count" ] || [ "$gpu_count" = "0" ]; then
        info "No GPU detected in cluster"
        return 1
    else
        info "Found $gpu_count GPU(s) in cluster"
        return 0
    fi
}

# Determine deployment variant
if [ "$VARIANT" = "auto" ]; then
    if detect_gpu; then
        VARIANT="gpu"
        info "Auto-selected GPU deployment"
    else
        VARIANT="cpu"
        info "Auto-selected CPU deployment"
    fi
fi

# Set deployment file
if [ "$VARIANT" = "gpu" ]; then
    DEPLOYMENT_FILE="deploy/kubernetes/deployment-gpu.yaml"
else
    DEPLOYMENT_FILE="deploy/kubernetes/deployment.yaml"
fi

# Create namespace if not exists
step "Ensuring namespace exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Deploy resources
step "Deploying ConfigMap..."
kubectl apply -f deploy/kubernetes/configmap.yaml -n "$NAMESPACE"

step "Deploying PVC..."
kubectl apply -f deploy/kubernetes/pvc.yaml -n "$NAMESPACE"

step "Deploying ServiceAccount..."
kubectl apply -f deploy/kubernetes/serviceaccount.yaml -n "$NAMESPACE"

step "Deploying FL xApp ($VARIANT)..."
kubectl apply -f "$DEPLOYMENT_FILE" -n "$NAMESPACE"

step "Deploying Service..."
kubectl apply -f deploy/kubernetes/service.yaml -n "$NAMESPACE"

info "Deployment applied successfully!"

# Wait for deployment
if [ "$WAIT" = true ]; then
    step "Waiting for deployment to be ready..."
    kubectl rollout status deployment/federated-learning -n "$NAMESPACE" --timeout=5m

    if [ $? -eq 0 ]; then
        info "Deployment is ready!"
    else
        error "Deployment failed to become ready"
    fi
fi

# Show deployment status
echo ""
step "Deployment status:"
kubectl get all -n "$NAMESPACE" -l app=federated-learning

echo ""
step "Pod logs (last 20 lines):"
kubectl logs -n "$NAMESPACE" -l app=federated-learning --tail=20 2>/dev/null || \
    warn "Pods not ready yet, skipping logs"

echo ""
info "Deployment completed!"
echo ""
info "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE -l app=federated-learning"
echo "  kubectl logs -n $NAMESPACE -l app=federated-learning -f"
echo "  kubectl describe pod -n $NAMESPACE -l app=federated-learning"
echo "  kubectl exec -n $NAMESPACE -it \$(kubectl get pod -n $NAMESPACE -l app=federated-learning -o jsonpath='{.items[0].metadata.name}') -- bash"
