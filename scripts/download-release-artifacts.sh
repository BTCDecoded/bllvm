#!/bin/bash
#
# Download artifacts from an existing GitHub release
#
# Usage: download-release-artifacts.sh <repo> <version_tag> <output_dir> [org] [platform]
#

set -euo pipefail

REPO="${1:-}"
VERSION_TAG="${2:-}"
OUTPUT_DIR="${3:-}"
ORG="${4:-BTCDecoded}"
PLATFORM="${5:-linux-x86_64}"

if [ -z "$REPO" ] || [ -z "$VERSION_TAG" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <repo> <version_tag> <output_dir> [org] [platform]" >&2
    exit 1
fi

# Get token from environment
TOKEN="${GITHUB_TOKEN:-${REPO_ACCESS_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
    echo "Error: GITHUB_TOKEN or REPO_ACCESS_TOKEN required" >&2
    exit 1
fi

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get release information
log_info "Fetching release information for ${ORG}/${REPO}@${VERSION_TAG}..."

RELEASE_JSON=$(curl -s \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${ORG}/${REPO}/releases/tags/${VERSION_TAG}")

if [ -z "$RELEASE_JSON" ] || echo "$RELEASE_JSON" | jq -e '.id' >/dev/null 2>&1; then
    RELEASE_ID=$(echo "$RELEASE_JSON" | jq -r '.id // empty')
    if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
        log_error "Release ${VERSION_TAG} not found for ${ORG}/${REPO}"
        exit 1
    fi
else
    log_error "Failed to fetch release information"
    exit 1
fi

# Get assets
ASSETS_JSON=$(echo "$RELEASE_JSON" | jq -r '.assets[]?')

if [ -z "$ASSETS_JSON" ]; then
    log_error "No assets found in release ${VERSION_TAG}"
    exit 1
fi

# Download relevant assets based on platform
DOWNLOADED=0

# Determine file patterns based on platform
if [[ "$PLATFORM" == *"windows"* ]]; then
    PATTERNS=("*.zip" "*windows*" "SHA256SUMS-windows*")
    BINARIES_DIR="${OUTPUT_DIR}/binaries-windows"
else
    PATTERNS=("*.tar.gz" "*linux*" "SHA256SUMS-linux*")
    BINARIES_DIR="${OUTPUT_DIR}/binaries"
fi

mkdir -p "$BINARIES_DIR"

# Download each asset
echo "$RELEASE_JSON" | jq -r '.assets[] | "\(.name)|\(.browser_download_url)"' | while IFS='|' read -r name url; do
    # Check if asset matches platform patterns
    MATCH=0
    for pattern in "${PATTERNS[@]}"; do
        if [[ "$name" == $pattern ]]; then
            MATCH=1
            break
        fi
    done
    
    # Also download SHA256SUMS files and RELEASE_NOTES.md regardless of platform
    if [[ "$name" == "SHA256SUMS"* ]] || [[ "$name" == "RELEASE_NOTES.md" ]] || [[ "$name" == "*.sig" ]]; then
        MATCH=1
    fi
    
    if [ "$MATCH" -eq 1 ]; then
        log_info "Downloading: $name"
        
        # Determine output location
        if [[ "$name" == *.tar.gz ]] || [[ "$name" == *.zip ]]; then
            # Extract binaries from archives if needed, or just download
            OUTPUT_FILE="${OUTPUT_DIR}/${name}"
        elif [[ "$name" == "SHA256SUMS"* ]]; then
            OUTPUT_FILE="${OUTPUT_DIR}/${name}"
        elif [[ "$name" == "RELEASE_NOTES.md" ]]; then
            OUTPUT_FILE="${OUTPUT_DIR}/${name}"
        else
            OUTPUT_FILE="${OUTPUT_DIR}/${name}"
        fi
        
        # Download the asset
        if curl -sL -H "Authorization: token $TOKEN" \
            -H "Accept: application/octet-stream" \
            "$url" -o "$OUTPUT_FILE"; then
            log_success "Downloaded: $name"
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            log_error "Failed to download: $name"
        fi
    fi
done

if [ "$DOWNLOADED" -eq 0 ]; then
    log_error "No matching artifacts found for platform ${PLATFORM}"
    exit 1
fi

# Verify downloaded checksums if available
log_info "Verifying downloaded artifact checksums..."
SHA256_FILE=""
if [[ "$PLATFORM" == *"windows"* ]]; then
    SHA256_FILE="${OUTPUT_DIR}/SHA256SUMS-windows-x86_64"
else
    SHA256_FILE="${OUTPUT_DIR}/SHA256SUMS-linux-x86_64"
fi

if [ -f "$SHA256_FILE" ]; then
    # Verify checksums for binaries
    if [[ "$PLATFORM" == *"windows"* ]] && [ -d "${OUTPUT_DIR}/binaries-windows" ]; then
        cd "${OUTPUT_DIR}/binaries-windows"
        if sha256sum -c "../$(basename "$SHA256_FILE")" 2>/dev/null; then
            log_success "Checksums verified for Windows binaries"
        else
            log_error "Checksum verification failed for Windows binaries"
            exit 1
        fi
        cd - > /dev/null
    elif [[ "$PLATFORM" != *"windows"* ]] && [ -d "${OUTPUT_DIR}/binaries" ]; then
        cd "${OUTPUT_DIR}/binaries"
        if sha256sum -c "../$(basename "$SHA256_FILE")" 2>/dev/null; then
            log_success "Checksums verified for Linux binaries"
        else
            log_error "Checksum verification failed for Linux binaries"
            exit 1
        fi
        cd - > /dev/null
    fi
else
    log_warn "No SHA256SUMS file found for verification (continuing anyway)"
fi

log_success "Downloaded and verified $DOWNLOADED artifact(s) to ${OUTPUT_DIR}"

