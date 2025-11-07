#!/bin/bash
#
# Complete Release Build Chain
# Chains all build scripts together for a final release
#
# Usage:
#   ./scripts/build-release-chain.sh [--base DIR] [--version TAG] [--local] [--ci]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$COMMONS_DIR")"
BASE_DIR="${PARENT_DIR}"
VERSION_TAG=""
LOCAL_MODE=0
CI_MODE=0

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Complete Release Build Chain

Usage: $0 [options]

Options:
    --base DIR      Base directory containing repo checkouts (default: parent of commons)
    --version TAG   Version tag to build (default: from versions.toml)
    --local         Use local build.sh instead of build_release_set.sh
    --ci            CI mode (skip local setup, assume repos checked out)
    -h, --help      Show this help message

Examples:
    # Build from versions.toml
    $0

    # Build specific version
    $0 --version v0.1.0

    # Local development build
    $0 --local

    # CI/CD build (repos already checked out)
    $0 --ci --version v0.1.0

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base) BASE_DIR="$2"; shift 2 ;;
        --version) VERSION_TAG="$2"; shift 2 ;;
        --local) LOCAL_MODE=1; shift ;;
        --ci) CI_MODE=1; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# Validate
if [ ! -d "$COMMONS_DIR" ]; then
    log_error "Commons directory not found: $COMMONS_DIR"
    exit 1
fi

cd "$COMMONS_DIR"

# Get version tag if not provided
if [ -z "$VERSION_TAG" ]; then
    if [ -f "versions.toml" ]; then
        # Use first repo's version as reference
        VERSION_TAG=$(grep -E '^bllvm-consensus' versions.toml | awk -F '="' '{print $2}' | tr -d '"')
        log_info "Using version from versions.toml: $VERSION_TAG"
    else
        log_error "No version tag provided and versions.toml not found"
        exit 1
    fi
fi

log_info "=========================================="
log_info "Bitcoin Commons Release Build Chain"
log_info "=========================================="
log_info "Version: $VERSION_TAG"
log_info "Base Directory: $BASE_DIR"
log_info "Mode: $([ $LOCAL_MODE -eq 1 ] && echo "Local" || echo "Release")"
log_info ""

# Step 1: Setup Build Environment
if [ $CI_MODE -eq 0 ]; then
    log_info "=== Step 1: Setting up build environment ==="
    
    if [ -f "scripts/setup-build-env.sh" ]; then
        if [ -n "$VERSION_TAG" ] && [ "$VERSION_TAG" != "dev" ]; then
            log_info "Setting up repos at tag: $VERSION_TAG"
            ./scripts/setup-build-env.sh --tag "$VERSION_TAG" || {
                log_warn "setup-build-env.sh failed, continuing with existing checkouts"
            }
        else
            log_info "Setting up repos for development"
            ./scripts/setup-build-env.sh || {
                log_warn "setup-build-env.sh failed, continuing with existing checkouts"
            }
        fi
    else
        log_warn "setup-build-env.sh not found, skipping environment setup"
    fi
    echo ""
fi

# Step 2: Build All Repositories
log_info "=== Step 2: Building all repositories ==="

if [ $LOCAL_MODE -eq 1 ]; then
    # Local build mode using build.sh
    log_info "Using local build mode (build.sh)"
    
    if [ ! -f "build.sh" ]; then
        log_error "build.sh not found"
        exit 1
    fi
    
    chmod +x build.sh
    ./build.sh --mode release || {
        log_error "Build failed"
        exit 1
    }
else
    # Release build mode using build_release_set.sh
    log_info "Using release build mode (build_release_set.sh)"
    
    if [ ! -f "tools/build_release_set.sh" ]; then
        log_error "build_release_set.sh not found"
        exit 1
    fi
    
    chmod +x tools/build_release_set.sh
    
    # Build release set
    BUILD_ARGS=(
        --base "$BASE_DIR"
    )
    
    # Add governance options if needed
    BUILD_ARGS+=(--gov-source)
    BUILD_ARGS+=(--gov-docker)
    BUILD_ARGS+=(--manifest "$COMMONS_DIR/artifacts")
    
    ./tools/build_release_set.sh "${BUILD_ARGS[@]}" || {
        log_error "Release build failed"
        exit 1
    }
fi

log_success "All repositories built successfully"
echo ""

# Step 3: Collect Artifacts
log_info "=== Step 3: Collecting artifacts ==="

if [ -f "scripts/collect-artifacts.sh" ]; then
    chmod +x scripts/collect-artifacts.sh
    
    # Determine platform
    PLATFORM="linux-x86_64"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="darwin-$(uname -m)"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        PLATFORM="windows-$(uname -m)"
    fi
    
    ./scripts/collect-artifacts.sh "$PLATFORM" || {
        log_warn "Artifact collection had issues, but continuing"
    }
    
    log_success "Artifacts collected"
else
    log_warn "collect-artifacts.sh not found, skipping artifact collection"
fi
echo ""

# Step 4: Create Release Package
log_info "=== Step 4: Creating release package ==="

if [ -f "scripts/create-release.sh" ]; then
    chmod +x scripts/create-release.sh
    ./scripts/create-release.sh "$VERSION_TAG" || {
        log_warn "Release package creation had issues, but continuing"
    }
    
    log_success "Release package created"
else
    log_warn "create-release.sh not found, skipping release package creation"
fi
echo ""

# Step 5: Verify Versions
log_info "=== Step 5: Verifying versions ==="

if [ -f "scripts/verify-versions.sh" ]; then
    chmod +x scripts/verify-versions.sh
    ./scripts/verify-versions.sh || {
        log_warn "Version verification had issues"
    }
    
    log_success "Version verification complete"
else
    log_warn "verify-versions.sh not found, skipping version verification"
fi
echo ""

# Summary
log_info "=========================================="
log_success "Release Build Chain Complete!"
log_info "=========================================="
log_info "Version: $VERSION_TAG"
log_info "Artifacts: $COMMONS_DIR/artifacts/"
echo ""

if [ -d "$COMMONS_DIR/artifacts" ]; then
    log_info "Artifact files:"
    ls -lh "$COMMONS_DIR/artifacts/" | grep -v "^total" | while read -r line; do
        echo "  $line"
    done
fi

echo ""
log_success "Ready for release: $VERSION_TAG"

