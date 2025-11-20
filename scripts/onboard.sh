#!/bin/bash
# FL xApp Onboarding Script
# Deploy using O-RAN SC xApp Onboarder (official method)

set -e

# Configuration
ONBOARDER_URL="${ONBOARDER_URL:-http://appmgr-service.ricplt:8080}"
CHART_REPO_URL="${CHART_REPO_URL:-http://chartmuseum.ricplt:8080}"
DESCRIPTOR_FILE="${DESCRIPTOR_FILE:-xapp-descriptor.json}"

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
Usage: $0 [OPTIONS] [ACTION]

Onboard FL xApp using O-RAN SC xApp Onboarder

ACTION:
  onboard   Onboard the xApp (default)
  install   Install onboarded xApp
  upgrade   Upgrade installed xApp
  status    Check xApp status
  delete    Delete xApp

OPTIONS:
  -u, --url URL              Onboarder URL (default: http://appmgr-service.ricplt:8080)
  -d, --descriptor FILE      xApp descriptor file (default: xapp-descriptor.json)
  -h, --help                 Show this help

Examples:
  $0 onboard                 # Onboard the xApp
  $0 install                 # Install after onboarding
  $0 status                  # Check status
  $0 -u http://localhost:8080 onboard  # Custom onboarder URL

Prerequisites:
  - RIC Platform with App Manager deployed
  - xApp Onboarder service running
  - Network connectivity to onboarder

EOF
    exit 0
}

# Parse arguments
ACTION="onboard"

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            ONBOARDER_URL="$2"
            shift 2
            ;;
        -d|--descriptor)
            DESCRIPTOR_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        onboard|install|upgrade|status|delete)
            ACTION="$1"
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
if ! command -v curl &> /dev/null; then
    error "curl is not installed"
fi

if ! command -v jq &> /dev/null; then
    error "jq is not installed"
fi

# Check descriptor file
if [ ! -f "$DESCRIPTOR_FILE" ]; then
    error "Descriptor file not found: $DESCRIPTOR_FILE"
fi

info "Onboarding configuration:"
info "  Onboarder URL: $ONBOARDER_URL"
info "  Descriptor: $DESCRIPTOR_FILE"
info "  Action: $ACTION"

# Check onboarder connectivity
step "Checking xApp Onboarder connectivity..."
if ! curl -s -f "${ONBOARDER_URL}/health" &> /dev/null; then
    warn "Cannot reach xApp Onboarder at $ONBOARDER_URL"
    warn "Make sure RIC Platform and xApp Onboarder are running"
    error "Onboarder not accessible"
fi
info "Onboarder is accessible"

# Action functions
do_onboard() {
    step "Onboarding xApp..."

    # Validate descriptor
    if ! jq empty "$DESCRIPTOR_FILE" 2>/dev/null; then
        error "Invalid JSON in descriptor file"
    fi

    # Extract xApp name and version
    local xapp_name=$(jq -r '.config.xapp_name' "$DESCRIPTOR_FILE")
    local xapp_version=$(jq -r '.config.version' "$DESCRIPTOR_FILE")

    info "Onboarding $xapp_name:$xapp_version..."

    # POST descriptor to onboarder
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @"$DESCRIPTOR_FILE" \
        "${ONBOARDER_URL}/api/v1/onboard/download" \
        2>&1)

    if echo "$response" | jq -e '.status == "success"' &> /dev/null; then
        info "Successfully onboarded $xapp_name:$xapp_version"
        info "xApp is now available for installation"
    else
        error "Failed to onboard xApp: $response"
    fi
}

do_install() {
    step "Installing xApp..."

    local xapp_name=$(jq -r '.config.xapp_name' "$DESCRIPTOR_FILE")
    local xapp_version=$(jq -r '.config.version' "$DESCRIPTOR_FILE")

    info "Installing $xapp_name:$xapp_version..."

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$xapp_name\",\"version\":\"$xapp_version\"}" \
        "${ONBOARDER_URL}/api/v1/xapps" \
        2>&1)

    if echo "$response" | jq -e '.status == "success"' &> /dev/null; then
        info "Successfully installed $xapp_name"
        info "Use './scripts/onboard.sh status' to check status"
    else
        error "Failed to install xApp: $response"
    fi
}

do_upgrade() {
    step "Upgrading xApp..."

    local xapp_name=$(jq -r '.config.xapp_name' "$DESCRIPTOR_FILE")
    local xapp_version=$(jq -r '.config.version' "$DESCRIPTOR_FILE")

    info "Upgrading $xapp_name to $xapp_version..."

    local response=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d "{\"version\":\"$xapp_version\"}" \
        "${ONBOARDER_URL}/api/v1/xapps/$xapp_name" \
        2>&1)

    if echo "$response" | jq -e '.status == "success"' &> /dev/null; then
        info "Successfully upgraded $xapp_name"
    else
        error "Failed to upgrade xApp: $response"
    fi
}

do_status() {
    step "Checking xApp status..."

    local xapp_name=$(jq -r '.config.xapp_name' "$DESCRIPTOR_FILE")

    info "Getting status for $xapp_name..."

    local response=$(curl -s -X GET \
        "${ONBOARDER_URL}/api/v1/xapps/$xapp_name" \
        2>&1)

    if echo "$response" | jq -e '.' &> /dev/null; then
        echo "$response" | jq .
    else
        error "Failed to get xApp status: $response"
    fi
}

do_delete() {
    step "Deleting xApp..."

    local xapp_name=$(jq -r '.config.xapp_name' "$DESCRIPTOR_FILE")

    info "Deleting $xapp_name..."

    read -p "Are you sure you want to delete $xapp_name? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Deletion cancelled"
        exit 0
    fi

    local response=$(curl -s -X DELETE \
        "${ONBOARDER_URL}/api/v1/xapps/$xapp_name" \
        2>&1)

    if echo "$response" | jq -e '.status == "success"' &> /dev/null; then
        info "Successfully deleted $xapp_name"
    else
        error "Failed to delete xApp: $response"
    fi
}

# Execute action
case $ACTION in
    onboard)
        do_onboard
        ;;
    install)
        do_install
        ;;
    upgrade)
        do_upgrade
        ;;
    status)
        do_status
        ;;
    delete)
        do_delete
        ;;
    *)
        error "Unknown action: $ACTION"
        ;;
esac

info "Action completed successfully!"
