#!/bin/bash
#
# Setup build environment by checking out all required repositories
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$COMMONS_DIR")"

# Configuration
ORG="BTCDecoded"
TAG="${1:-}"
REPOS=("bllvm-consensus" "bllvm-protocol" "bllvm-node" "bllvm-sdk" "governance-app")

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

clone_or_update_repo() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    
    if [ -d "$repo_path" ]; then
        log_info "Repository exists: ${repo}"
        pushd "$repo_path" > /dev/null
        
        # Update if tag specified
        if [ -n "$TAG" ]; then
            log_info "Checking out tag: ${TAG}"
            git fetch --tags
            git checkout "$TAG" 2>/dev/null || {
                log_error "Tag ${TAG} not found in ${repo}"
                popd > /dev/null
                return 1
            }
        else
            # Update to latest
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        fi
        
        popd > /dev/null
        log_success "Repository ready: ${repo}"
    else
        log_info "Cloning repository: ${repo}"
        
        local repo_url="https://github.com/${ORG}/${repo}.git"
        
        pushd "$PARENT_DIR" > /dev/null
        
        if ! git clone "$repo_url" "$repo"; then
            log_error "Failed to clone ${repo}"
            popd > /dev/null
            return 1
        fi
        
        if [ -n "$TAG" ]; then
            pushd "$repo" > /dev/null
            git checkout "$TAG" 2>/dev/null || {
                log_error "Tag ${TAG} not found in ${repo}"
                popd > /dev/null
                return 1
            }
            popd > /dev/null
        fi
        
        popd > /dev/null
        log_success "Cloned repository: ${repo}"
    fi
    
    return 0
}

main() {
    log_info "Setting up build environment"
    
    if [ -n "$TAG" ]; then
        log_info "Target tag: ${TAG}"
    else
        log_info "Using latest from main/master branches"
    fi
    
    mkdir -p "$PARENT_DIR"
    
    local failed=0
    for repo in "${REPOS[@]}"; do
        if ! clone_or_update_repo "$repo"; then
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log_success "Build environment ready!"
        log_info "Repositories located in: ${PARENT_DIR}"
    else
        log_error "Setup completed with ${failed} failure(s)"
        exit 1
    fi
}

main "$@"

