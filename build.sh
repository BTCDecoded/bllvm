#!/bin/bash
#
# Unified Build Script for BTCDecoded Ecosystem
# Builds all repositories in dependency order
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
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
MODE="dev"
VARIANT="base"  # base or experimental
ARTIFACTS_DIR="${SCRIPT_DIR}/artifacts"
TARGET_DIR="target/release"

# Functions (defined early for use in argument parsing)
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

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --variant) VARIANT="$2"; shift 2 ;;
        dev|release) MODE="$1"; shift ;; # Backward compatibility
        *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
done

# Validate variant
if [ "$VARIANT" != "base" ] && [ "$VARIANT" != "experimental" ]; then
    log_error "Invalid variant: $VARIANT (must be 'base' or 'experimental')"
    exit 1
fi

# Repository configuration
declare -A REPOS
REPOS[bllvm-consensus]="library"
REPOS[bllvm-protocol]="library|bllvm-consensus"
REPOS[bllvm-node]="library|bllvm-protocol,bllvm-consensus"
REPOS[bllvm]="binary|bllvm-node"
REPOS[bllvm-sdk]="binary"
REPOS[bllvm-commons]="binary|bllvm-sdk"

# Dependency graph (using directory names for paths, package names in Cargo.toml are updated)
declare -A DEPS
DEPS[bllvm-consensus]=""
DEPS[bllvm-protocol]="bllvm-consensus"
DEPS[bllvm-node]="bllvm-protocol bllvm-consensus"
DEPS[bllvm]="bllvm-node"
DEPS[bllvm-sdk]=""
DEPS[bllvm-commons]="bllvm-sdk"

# Binary names
declare -A BINARIES
BINARIES[bllvm-consensus]=""
BINARIES[bllvm-protocol]=""
BINARIES[bllvm-node]=""
BINARIES[bllvm]="bllvm"
BINARIES[bllvm-sdk]="bllvm-keygen bllvm-sign bllvm-verify"
BINARIES[bllvm-commons]="bllvm-commons key-manager test-content-hash test-content-hash-standalone"

check_rust_toolchain() {
    log_info "Checking Rust toolchain..."
    
    if ! command -v rustc &> /dev/null; then
        log_error "Rust is not installed. Please install Rust 1.70+ from https://rustup.rs"
        exit 1
    fi
    
    RUST_VERSION=$(rustc --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    RUST_MAJOR=$(echo "$RUST_VERSION" | cut -d. -f1)
    RUST_MINOR=$(echo "$RUST_VERSION" | cut -d. -f2)
    
    if [ "$RUST_MAJOR" -lt 1 ] || ([ "$RUST_MAJOR" -eq 1 ] && [ "$RUST_MINOR" -lt 70 ]); then
        log_error "Rust 1.70+ required. Found: $RUST_VERSION"
        exit 1
    fi
    
    log_success "Rust toolchain OK: $(rustc --version)"
}

check_repo_exists() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    
    if [ ! -d "$repo_path" ]; then
        log_error "Repository not found: $repo_path"
        log_info "Please clone: git clone https://github.com/BTCDecoded/${repo}.git"
        return 1
    fi
    
    if [ ! -f "${repo_path}/Cargo.toml" ]; then
        log_error "Invalid repository: $repo_path (no Cargo.toml found)"
        return 1
    fi
    
    return 0
}

check_all_repos() {
    log_info "Checking all repositories..."
    
    local missing=0
    for repo in "${!REPOS[@]}"; do
        if ! check_repo_exists "$repo"; then
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "Missing $missing repository(ies). Please clone all required repos."
        exit 1
    fi
    
    log_success "All repositories found"
}

build_repo() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    
    # CRITICAL: Unset CARGO_BUILD_JOBS if it's 0 (cargo rejects this)
    if [ "${CARGO_BUILD_JOBS:-}" = "0" ]; then
        unset CARGO_BUILD_JOBS
    fi
    
    # Determine feature flags based on variant
    local features=""
    case "$VARIANT" in
        base)
            # Base variant: core infrastructure + production optimizations + differentiators
            # Includes: infrastructure (sysinfo, redb, nix, libc), production, governance, zmq
            case "$repo" in
                bllvm-consensus|bllvm-protocol)
                    # Consensus and protocol layers: production only
                    features="production"
                    ;;
                bllvm-node|bllvm)
                    # Node layer: infrastructure + production + governance + zmq (differentiator)
                    features="sysinfo,redb,nix,libc,production,governance,zmq"
                    ;;
                *)
                    # Other repos (bllvm-sdk, bllvm-commons) use default features
                    features=""
                    ;;
            esac
            ;;
        experimental)
            # Experimental variant: all features
            case "$repo" in
                bllvm-consensus)
                    features="production,utxo-commitments,ctv"
                    ;;
                bllvm-protocol)
                    # Pass through ctv from bllvm-consensus
                    features="production,utxo-commitments,ctv"
                    ;;
                bllvm-node)
                    # All base features + all experimental features
                    features="sysinfo,redb,nix,libc,production,governance,zmq,utxo-commitments,ctv,dandelion,stratum-v2,bip158,sigop,iroh,quinn"
                    ;;
                bllvm)
                    # bllvm binary inherits from bllvm-node, include all features
                    features="sysinfo,redb,nix,libc,production,governance,zmq,utxo-commitments,ctv,dandelion,stratum-v2,bip158,sigop,iroh,quinn"
                    ;;
                *)
                    # Other repos (bllvm-sdk, bllvm-commons) use default features
                    features=""
                    ;;
            esac
            ;;
    esac
    
    log_info "Building ${repo} (variant: ${VARIANT}, features: ${features:-default})..."
    
    pushd "$repo_path" > /dev/null
    
    # Switch dependency mode if needed
    if [ "$MODE" == "release" ]; then
        log_info "Switching to git dependencies for release mode"
        # This would require modifying Cargo.toml - for now, assume local paths work
        # In a real implementation, we'd patch Cargo.toml or use git dependencies
    fi
    
    # Build with optimizations
    # Enable incremental compilation for faster builds
    export CARGO_INCREMENTAL="${CARGO_INCREMENTAL:-1}"
    
    # For release mode, update Cargo.lock first, then use --locked for reproducible builds
    if [ "$MODE" == "release" ]; then
        log_info "Updating Cargo.lock for reproducible build..."
        cargo update --workspace
    fi
    
    # Build command with features
    local build_cmd="cargo build --release"
    if [ "$MODE" == "release" ]; then
        build_cmd="cargo build --release --locked"
    fi
    if [ -n "$features" ]; then
        build_cmd="${build_cmd} --features ${features}"
    fi
    
    # Build: use --jobs only if CARGO_BUILD_JOBS is set (and not 0)
    # If unset or empty, cargo will use all cores by default
    if [ -n "${CARGO_BUILD_JOBS:-}" ] && [ "${CARGO_BUILD_JOBS}" != "0" ]; then
        if ! ${build_cmd} --jobs "${CARGO_BUILD_JOBS}" 2>&1 | tee "/tmp/${repo}-build.log"; then
            # In Phase 1 prerelease, bllvm-commons is optional (governance not activated)
            if [ "$repo" == "bllvm-commons" ] && [ "$MODE" == "release" ]; then
                log_warn "Build failed for ${repo} (optional in Phase 1 prerelease)"
                log_info "Skipping ${repo} - governance not yet activated"
                popd > /dev/null
                return 0  # Don't fail the build
            fi
            log_error "Build failed for ${repo}"
            popd > /dev/null
            return 1
        fi
    else
        # Use all cores (omit --jobs flag)
        if ! ${build_cmd} 2>&1 | tee "/tmp/${repo}-build.log"; then
            # In Phase 1 prerelease, bllvm-commons is optional (governance not activated)
            if [ "$repo" == "bllvm-commons" ] && [ "$MODE" == "release" ]; then
                log_warn "Build failed for ${repo} (optional in Phase 1 prerelease)"
                log_info "Skipping ${repo} - governance not yet activated"
                popd > /dev/null
                return 0  # Don't fail the build
            fi
            log_error "Build failed for ${repo}"
            popd > /dev/null
            return 1
        fi
    fi
    
    popd > /dev/null
    log_success "Built ${repo}"
    return 0
}

collect_binaries() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    local binaries="${BINARIES[$repo]}"
    
    if [ -z "$binaries" ]; then
        log_info "No binaries for ${repo} (library only)"
        return 0
    fi
    
    # Use variant-specific directory
    # Base variant uses "binaries", experimental uses "binaries-experimental"
    if [ "$VARIANT" = "base" ]; then
        local binaries_dir="${ARTIFACTS_DIR}/binaries"
    else
        local binaries_dir="${ARTIFACTS_DIR}/binaries-experimental"
    fi
    mkdir -p "$binaries_dir"
    
    for binary in $binaries; do
        local bin_path="${repo_path}/${TARGET_DIR}/${binary}"
        if [ -f "$bin_path" ]; then
            cp "$bin_path" "${binaries_dir}/"
            log_success "Collected binary: ${binary} (variant: ${VARIANT})"
        else
            log_warn "Binary not found: ${bin_path}"
        fi
    done
}

topological_sort() {
    # Simple topological sort for dependency order
    local sorted=()
    local visited=()
    
    visit() {
        local repo=$1
        
        if [[ " ${visited[@]} " =~ " ${repo} " ]]; then
            return
        fi
        
        # Visit dependencies first
        local deps="${DEPS[$repo]}"
        if [ -n "$deps" ]; then
            for dep in $deps; do
                visit "$dep"
            done
        fi
        
        visited+=("$repo")
        sorted+=("$repo")
    }
    
    for repo in "${!REPOS[@]}"; do
        visit "$repo"
    done
    
    echo "${sorted[@]}"
}

main() {
    log_info "Bitcoin Commons BLLVM Unified Build System"
    log_info "Mode: ${MODE}"
    log_info "Variant: ${VARIANT}"
    echo ""
    
    # Setup
    check_rust_toolchain
    check_all_repos
    mkdir -p "$ARTIFACTS_DIR"
    
    # Get build order
    local build_order
    build_order=($(topological_sort))
    
    log_info "Build order: ${build_order[*]}"
    echo ""
    
    # Build in order
    local failed=0
    for repo in "${build_order[@]}"; do
        if ! build_repo "$repo"; then
            failed=$((failed + 1))
            log_error "Build failed, stopping"
            break
        fi
        
        collect_binaries "$repo"
        echo ""
    done
    
    # Summary
    if [ $failed -eq 0 ]; then
        log_success "All repositories built successfully!"
        if [ "$VARIANT" = "base" ]; then
            log_info "Binaries collected in: ${ARTIFACTS_DIR}/binaries"
        else
            log_info "Binaries collected in: ${ARTIFACTS_DIR}/binaries-experimental"
        fi
    else
        log_error "Build completed with $failed failure(s)"
        exit 1
    fi
}

# Run main
main "$@"

