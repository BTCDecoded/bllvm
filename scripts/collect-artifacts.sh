#!/bin/bash
#
# Collect all built binaries into release artifacts
# Creates separate archives for bllvm binary and governance tools
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$COMMONS_DIR")"
ARTIFACTS_DIR="${COMMONS_DIR}/artifacts"
PLATFORM="${1:-linux-x86_64}"
VARIANT="${2:-base}"  # base or experimental

# Validate variant
if [ "$VARIANT" != "base" ] && [ "$VARIANT" != "experimental" ]; then
    echo "ERROR: Invalid variant: $VARIANT (must be 'base' or 'experimental')"
    exit 1
fi

# Determine target directory and binary extension based on platform
if [[ "$PLATFORM" == *"windows"* ]]; then
    TARGET_DIR="target/x86_64-pc-windows-gnu/release"
    BIN_EXT=".exe"
    if [ "$VARIANT" = "base" ]; then
        BLLVM_DIR="${ARTIFACTS_DIR}/bllvm-windows"
        GOVERNANCE_DIR="${ARTIFACTS_DIR}/governance-windows"
    else
        BLLVM_DIR="${ARTIFACTS_DIR}/bllvm-experimental-windows"
        GOVERNANCE_DIR="${ARTIFACTS_DIR}/governance-experimental-windows"
    fi
else
    TARGET_DIR="target/release"
    BIN_EXT=""
    if [ "$VARIANT" = "base" ]; then
        BLLVM_DIR="${ARTIFACTS_DIR}/bllvm-linux"
        GOVERNANCE_DIR="${ARTIFACTS_DIR}/governance-linux"
    else
        BLLVM_DIR="${ARTIFACTS_DIR}/bllvm-experimental-linux"
        GOVERNANCE_DIR="${ARTIFACTS_DIR}/governance-experimental-linux"
    fi
fi

# Binary mapping
declare -A REPO_BINARIES
REPO_BINARIES[bllvm]="bllvm"
REPO_BINARIES[bllvm-sdk]="bllvm-keygen bllvm-sign bllvm-verify"
REPO_BINARIES[bllvm-commons]="bllvm-commons key-manager test-content-hash test-content-hash-standalone"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warn() {
    echo "[WARN] $1"
}

collect_bllvm_binary() {
    local repo="bllvm"
    local repo_path="${PARENT_DIR}/${repo}"
    local binary="bllvm"
    local bin_path="${repo_path}/${TARGET_DIR}/${binary}${BIN_EXT}"
    
    mkdir -p "$BLLVM_DIR"
    
    if [ -f "$bin_path" ]; then
        cp "$bin_path" "${BLLVM_DIR}/"
        log_success "Collected: ${binary}${BIN_EXT}"
        return 0
    else
        log_warn "Binary not found: ${bin_path}"
        return 1
    fi
}

collect_governance_binaries() {
    mkdir -p "$GOVERNANCE_DIR"
    
    # Collect bllvm-sdk binaries
    local repo="bllvm-sdk"
    local repo_path="${PARENT_DIR}/${repo}"
    local binaries="${REPO_BINARIES[$repo]}"
    
    for binary in $binaries; do
        local bin_path="${repo_path}/${TARGET_DIR}/${binary}${BIN_EXT}"
        if [ -f "$bin_path" ]; then
            cp "$bin_path" "${GOVERNANCE_DIR}/"
            log_success "Collected: ${binary}${BIN_EXT}"
        else
            log_warn "Binary not found: ${bin_path}"
        fi
    done
    
    # Collect bllvm-commons binaries (Linux only)
    if [[ "$PLATFORM" != *"windows"* ]]; then
        local repo="bllvm-commons"
        local repo_path="${PARENT_DIR}/${repo}"
        local binaries="${REPO_BINARIES[$repo]}"
        
        for binary in $binaries; do
            local bin_path="${repo_path}/${TARGET_DIR}/${binary}${BIN_EXT}"
            if [ -f "$bin_path" ]; then
                cp "$bin_path" "${GOVERNANCE_DIR}/"
                log_success "Collected: ${binary}${BIN_EXT}"
            else
                log_warn "Binary not found: ${bin_path}"
            fi
        done
    fi
}

generate_checksums() {
    local dir=$1
    local checksum_file=$2
    
    if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        return 0
    fi
    
    log_info "Generating checksums for $(basename "$dir")..."
    
    pushd "$dir" > /dev/null
    
    if command -v sha256sum &> /dev/null; then
        sha256sum * > "$checksum_file" 2>/dev/null || true
        log_success "Generated ${checksum_file}"
    elif command -v shasum &> /dev/null; then
        shasum -a 256 * > "$checksum_file" 2>/dev/null || true
        log_success "Generated ${checksum_file}"
    else
        log_warn "No checksum tool found (sha256sum or shasum)"
    fi
    
    popd > /dev/null
}

create_archive() {
    local source_dir=$1
    local archive_name=$2
    local checksum_file=$3
    
    if [ ! -d "$source_dir" ] || [ -z "$(ls -A "$source_dir" 2>/dev/null)" ]; then
        log_warn "No binaries found in $source_dir, skipping archive creation"
        return 0
    fi
    
    pushd "$ARTIFACTS_DIR" > /dev/null
    
    # Create archive with binaries at root (no subdirectory)
    if [[ "$archive_name" == *.tar.gz ]]; then
        # Use -C to change directory, then archive contents directly
        tar -czf "$archive_name" -C "$source_dir" . "$checksum_file" 2>/dev/null || {
            # Fallback: create temp dir structure
            local temp_dir=$(mktemp -d)
            cp -r "$source_dir"/* "$temp_dir/" 2>/dev/null || true
            if [ -f "$checksum_file" ]; then
                cp "$checksum_file" "$temp_dir/" 2>/dev/null || true
            fi
            tar -czf "$archive_name" -C "$temp_dir" . 2>/dev/null || true
            rm -rf "$temp_dir"
        }
        log_success "Created: ${archive_name}"
    elif [[ "$archive_name" == *.zip ]]; then
        # For zip, cd into directory and add files from there
        pushd "$source_dir" > /dev/null
        zip -r "${ARTIFACTS_DIR}/${archive_name}" . 2>/dev/null || true
        popd > /dev/null
        # Add checksum file if it exists
        if [ -f "$checksum_file" ]; then
            zip -u "${ARTIFACTS_DIR}/${archive_name}" "$checksum_file" 2>/dev/null || true
        fi
        log_success "Created: ${archive_name}"
    fi
    
    popd > /dev/null
}

main() {
    log_info "Collecting artifacts for ${PLATFORM} (variant: ${VARIANT})..."
    
    # Collect bllvm binary separately
    if collect_bllvm_binary; then
        # Generate checksum for bllvm binary
        local bllvm_checksum
        if [ "$VARIANT" = "base" ]; then
            bllvm_checksum="${ARTIFACTS_DIR}/SHA256SUMS-bllvm-${PLATFORM}"
        else
            bllvm_checksum="${ARTIFACTS_DIR}/SHA256SUMS-bllvm-experimental-${PLATFORM}"
        fi
        generate_checksums "$BLLVM_DIR" "$bllvm_checksum"
        
        # Create archive for bllvm binary
        local bllvm_archive
        if [ "$VARIANT" = "base" ]; then
            if [[ "$PLATFORM" == *"windows"* ]]; then
                bllvm_archive="bllvm-${PLATFORM}.zip"
            else
                bllvm_archive="bllvm-${PLATFORM}.tar.gz"
            fi
        else
            if [[ "$PLATFORM" == *"windows"* ]]; then
                bllvm_archive="bllvm-experimental-${PLATFORM}.zip"
            else
                bllvm_archive="bllvm-experimental-${PLATFORM}.tar.gz"
            fi
        fi
        create_archive "$BLLVM_DIR" "$bllvm_archive" "$bllvm_checksum"
    fi
    
    # Collect governance binaries
    collect_governance_binaries
    
    if [ -d "$GOVERNANCE_DIR" ] && [ "$(ls -A "$GOVERNANCE_DIR" 2>/dev/null)" ]; then
        # Generate checksum for governance binaries
        local gov_checksum
        if [ "$VARIANT" = "base" ]; then
            gov_checksum="${ARTIFACTS_DIR}/SHA256SUMS-governance-${PLATFORM}"
        else
            gov_checksum="${ARTIFACTS_DIR}/SHA256SUMS-governance-experimental-${PLATFORM}"
        fi
        generate_checksums "$GOVERNANCE_DIR" "$gov_checksum"
        
        # Create archive for governance binaries
        local gov_archive
        if [ "$VARIANT" = "base" ]; then
            if [[ "$PLATFORM" == *"windows"* ]]; then
                gov_archive="bllvm-governance-${PLATFORM}.zip"
            else
                gov_archive="bllvm-governance-${PLATFORM}.tar.gz"
            fi
        else
            if [[ "$PLATFORM" == *"windows"* ]]; then
                gov_archive="bllvm-governance-experimental-${PLATFORM}.zip"
            else
                gov_archive="bllvm-governance-experimental-${PLATFORM}.tar.gz"
            fi
        fi
        create_archive "$GOVERNANCE_DIR" "$gov_archive" "$gov_checksum"
    fi
    
    log_success "Artifacts collected in: ${ARTIFACTS_DIR}"
}

main "$@"
