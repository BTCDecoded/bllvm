#!/bin/bash
#
# Simple Local Build Script
# Easy-to-use wrapper for local development builds
#
# Usage:
#   ./build-local.sh [--dev] [--release] [--clean] [--help]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="dev"
CLEAN=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Simple Local Build Script

Usage: $0 [options]

Options:
    --dev          Development build (default, uses local paths)
    --release      Release build (uses git dependencies)
    --clean        Clean before building
    -h, --help     Show this help message

Examples:
    # Quick development build
    $0

    # Clean release build
    $0 --release --clean

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev) MODE="dev"; shift ;;
        --release) MODE="release"; shift ;;
        --clean) CLEAN=1; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

cd "$SCRIPT_DIR"

log_info "=========================================="
log_info "Bitcoin Commons Local Build"
log_info "=========================================="
log_info "Mode: $MODE"
log_info ""

# Check if build.sh exists
if [ ! -f "build.sh" ]; then
    log_error "build.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Make executable
chmod +x build.sh

# Clean if requested
if [ $CLEAN -eq 1 ]; then
    log_info "Cleaning previous builds..."
    PARENT_DIR="$(dirname "$SCRIPT_DIR")"
    for repo in consensus-proof protocol-engine reference-node developer-sdk governance-app; do
        if [ -d "$PARENT_DIR/$repo" ]; then
            log_info "Cleaning $repo..."
            (cd "$PARENT_DIR/$repo" && cargo clean 2>/dev/null || true)
        fi
    done
    log_success "Clean complete"
    echo ""
fi

# Run build
log_info "Starting build..."
./build.sh --mode "$MODE"

log_success "Build complete!"
log_info "Binaries: $SCRIPT_DIR/artifacts/binaries/"

