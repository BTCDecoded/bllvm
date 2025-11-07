#!/bin/bash
#
# Verify version compatibility across repositories
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${COMMONS_DIR}/versions.toml"

REPO_NAME="${1:-}"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

check_versions_file() {
    if [ ! -f "$VERSIONS_FILE" ]; then
        log_error "Versions file not found: ${VERSIONS_FILE}"
        return 1
    fi
    
    return 0
}

verify_repo_version() {
    local repo=$1
    
    log_info "Verifying version for: ${repo}"
    
    # Extract version from versions.toml using grep/sed
    # In a real implementation, we'd use a TOML parser
    local version_line
    version_line=$(grep -A 3 "^\[versions\]" "$VERSIONS_FILE" | grep -A 3 "$repo" | grep "version" | head -1) || true
    
    if [ -z "$version_line" ]; then
        log_warn "Version not found in versions.toml for: ${repo}"
        return 1
    fi
    
    local version
    version=$(echo "$version_line" | sed -E 's/.*version = "([^"]+)".*/\1/')
    
    log_info "Version for ${repo}: ${version}"
    
    # Check if version follows semantic versioning
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        log_warn "Version ${version} does not follow semantic versioning (X.Y.Z)"
        return 1
    fi
    
    log_success "Version OK for ${repo}: ${version}"
    return 0
}

verify_dependencies() {
    local repo=$1
    
    log_info "Verifying dependencies for: ${repo}"
    
    # Extract requires from versions.toml
    local requires_line
    requires_line=$(grep -A 5 "$repo" "$VERSIONS_FILE" | grep "requires" | head -1) || true
    
    if [ -z "$requires_line" ]; then
        log_info "No dependencies required for: ${repo}"
        return 0
    fi
    
    log_info "Dependencies: ${requires_line}"
    # In a full implementation, we'd parse and verify each dependency version
    
    return 0
}

main() {
    if ! check_versions_file; then
        exit 1
    fi
    
    if [ -n "$REPO_NAME" ]; then
        # Verify single repo
        verify_repo_version "$REPO_NAME"
        verify_dependencies "$REPO_NAME"
    else
        # Verify all repos
        log_info "Verifying all repository versions..."
        
        local repos=("bllvm-consensus" "bllvm-protocol" "bllvm-node" "bllvm-sdk" "governance-app")
        
        local failed=0
        for repo in "${repos[@]}"; do
            if ! verify_repo_version "$repo"; then
                failed=$((failed + 1))
            fi
            verify_dependencies "$repo"
        done
        
        if [ $failed -eq 0 ]; then
            log_success "All version verifications passed"
        else
            log_warn "Version verification completed with ${failed} warning(s)"
        fi
    fi
}

main "$@"

