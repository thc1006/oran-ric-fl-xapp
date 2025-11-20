#!/bin/bash
# FL xApp Test Script
# Run tests and health checks

set -e

# Configuration
NAMESPACE="${NAMESPACE:-ricxapp}"
POD_NAME=""

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
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

fail() {
    echo -e "${RED}[✗]${NC} $1"
}

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [TEST_TYPE]

Run tests for FL xApp

TEST_TYPE:
  unit          Run unit tests
  integration   Run integration tests
  e2e           Run end-to-end tests
  health        Run health checks (default)
  all           Run all tests

OPTIONS:
  -n, --namespace NAMESPACE  Kubernetes namespace (default: ricxapp)
  -h, --help                 Show this help

Examples:
  $0                         # Run health checks
  $0 unit                    # Run unit tests
  $0 all                     # Run all tests

EOF
    exit 0
}

# Parse arguments
TEST_TYPE="health"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        unit|integration|e2e|health|all)
            TEST_TYPE="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Change to project root
cd "$(dirname "$0")/.."

# Get pod name
get_pod_name() {
    POD_NAME=$(kubectl get pod -n "$NAMESPACE" -l app=federated-learning -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -z "$POD_NAME" ]; then
        return 1
    fi
    return 0
}

# Unit tests
run_unit_tests() {
    step "Running unit tests..."

    if [ ! -d "tests/unit" ]; then
        warn "No unit tests found"
        return 0
    fi

    if command -v pytest &> /dev/null; then
        pytest tests/unit/ -v
    else
        warn "pytest not installed, skipping unit tests"
    fi
}

# Integration tests
run_integration_tests() {
    step "Running integration tests..."

    if [ ! -d "tests/integration" ]; then
        warn "No integration tests found"
        return 0
    fi

    if command -v pytest &> /dev/null; then
        pytest tests/integration/ -v
    else
        warn "pytest not installed, skipping integration tests"
    fi
}

# E2E tests
run_e2e_tests() {
    step "Running E2E tests..."

    if [ ! -d "tests/e2e" ]; then
        warn "No E2E tests found"
        return 0
    fi

    if command -v pytest &> /dev/null; then
        pytest tests/e2e/ -v
    else
        warn "pytest not installed, skipping E2E tests"
    fi
}

# Health checks
run_health_checks() {
    step "Running health checks..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found"
        exit 1
    fi

    # Check if pod exists
    if ! get_pod_name; then
        fail "FL xApp pod not found in namespace $NAMESPACE"
        exit 1
    fi

    success "Found FL xApp pod: $POD_NAME"

    # Check pod status
    step "Checking pod status..."
    local pod_status=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.phase}')
    if [ "$pod_status" = "Running" ]; then
        success "Pod is running"
    else
        fail "Pod status: $pod_status"
        exit 1
    fi

    # Check container ready
    step "Checking container readiness..."
    local ready=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.containerStatuses[0].ready}')
    if [ "$ready" = "true" ]; then
        success "Container is ready"
    else
        fail "Container is not ready"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" --tail=20
        exit 1
    fi

    # Get service endpoint
    local service_ip=$(kubectl get svc -n "$NAMESPACE" federated-learning-service -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    if [ -z "$service_ip" ]; then
        warn "Service not found, using pod IP"
        service_ip=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.podIP}')
    fi

    # Check liveness endpoint
    step "Checking liveness endpoint..."
    if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -sf http://localhost:8110/health/alive &> /dev/null; then
        success "Liveness check passed"
    else
        fail "Liveness check failed"
        exit 1
    fi

    # Check readiness endpoint
    step "Checking readiness endpoint..."
    if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -sf http://localhost:8110/health/ready &> /dev/null; then
        success "Readiness check passed"
    else
        fail "Readiness check failed"
        exit 1
    fi

    # Check FL status
    step "Checking FL status..."
    local fl_status=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -s http://localhost:8110/fl/status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")
    if [ "$fl_status" != "error" ]; then
        success "FL status: $fl_status"
    else
        warn "Could not retrieve FL status"
    fi

    # Check metrics
    step "Checking Prometheus metrics..."
    if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -sf http://localhost:8110/ric/v1/metrics &> /dev/null; then
        success "Metrics endpoint is accessible"
    else
        warn "Metrics endpoint not accessible"
    fi

    # Check GPU (if applicable)
    step "Checking GPU availability..."
    local gpu_status=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "False")
    if [ "$gpu_status" = "True" ]; then
        success "GPU is available and accessible"
        local gpu_count=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- python3 -c "import torch; print(torch.cuda.device_count())" 2>/dev/null)
        info "GPU count: $gpu_count"
    else
        info "Running in CPU mode"
    fi

    echo ""
    success "All health checks passed!"
}

# Run tests based on type
case $TEST_TYPE in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    e2e)
        run_e2e_tests
        ;;
    health)
        run_health_checks
        ;;
    all)
        run_unit_tests
        run_integration_tests
        run_e2e_tests
        run_health_checks
        ;;
    *)
        error "Unknown test type: $TEST_TYPE"
        exit 1
        ;;
esac

info "Tests completed successfully!"
