#!/bin/bash
# FL xApp Build Script
# Builds Docker images for CPU, GPU, or both versions

set -e

# Configuration
REGISTRY="${REGISTRY:-localhost:5000}"
IMAGE_NAME="${IMAGE_NAME:-fl-xapp}"
VERSION="${VERSION:-1.0.0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [VARIANT]

Build FL xApp Docker images

VARIANT:
  cpu       Build CPU version only (default)
  gpu       Build GPU version only
  both      Build both CPU and GPU versions
  optimized Build optimized CPU version

OPTIONS:
  -r, --registry REGISTRY   Docker registry (default: localhost:5000)
  -n, --name NAME          Image name (default: fl-xapp)
  -v, --version VERSION    Image version (default: 1.0.0)
  -p, --push               Push images after build
  -h, --help               Show this help

Examples:
  $0 cpu                   # Build CPU version
  $0 gpu                   # Build GPU version
  $0 both --push           # Build both and push
  $0 -r ghcr.io/org -n ric-fl both  # Custom registry and name

EOF
    exit 0
}

# Parse arguments
PUSH=false
VARIANT="cpu"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        cpu|gpu|both|optimized)
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
if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
fi

info "Build configuration:"
info "  Registry: $REGISTRY"
info "  Image: $IMAGE_NAME"
info "  Version: $VERSION"
info "  Variant: $VARIANT"
info "  Push: $PUSH"

# Build function
build_image() {
    local dockerfile=$1
    local tag_suffix=$2
    local full_tag="${REGISTRY}/${IMAGE_NAME}:${VERSION}${tag_suffix}"

    info "Building $full_tag..."

    docker build \
        -f "$dockerfile" \
        -t "$full_tag" \
        --label "org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --label "org.opencontainers.image.version=$VERSION" \
        --label "org.opencontainers.image.title=FL xApp" \
        --label "org.opencontainers.image.description=Federated Learning xApp for O-RAN" \
        .

    if [ $? -eq 0 ]; then
        info "Successfully built $full_tag"

        if [ "$PUSH" = true ]; then
            info "Pushing $full_tag..."
            docker push "$full_tag"
            if [ $? -eq 0 ]; then
                info "Successfully pushed $full_tag"
            else
                error "Failed to push $full_tag"
            fi
        fi
    else
        error "Failed to build $full_tag"
    fi
}

# Build based on variant
case $VARIANT in
    cpu)
        build_image "Dockerfile" ""
        ;;
    gpu)
        build_image "Dockerfile.gpu" "-gpu"
        ;;
    optimized)
        build_image "Dockerfile.optimized" "-optimized"
        ;;
    both)
        build_image "Dockerfile" ""
        build_image "Dockerfile.gpu" "-gpu"
        ;;
    *)
        error "Unknown variant: $VARIANT"
        ;;
esac

info "Build completed successfully!"

# Summary
echo ""
info "Built images:"
docker images | grep "$IMAGE_NAME" | grep "$VERSION"

echo ""
info "To deploy, run:"
echo "  ./scripts/deploy.sh $VARIANT"
