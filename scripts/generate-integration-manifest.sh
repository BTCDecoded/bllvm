#!/bin/bash
#
# Generate integration manifest for unified release
#
# Usage: generate-integration-manifest.sh <version_tag> <artifacts_dir> <output_file> [component_manifests...]
#

set -euo pipefail

VERSION_TAG="${1:-}"
ARTIFACTS_DIR="${2:-}"
OUTPUT_FILE="${3:-}"
shift 3 || true
COMPONENT_MANIFESTS=("$@")

if [ -z "$VERSION_TAG" ] || [ -z "$ARTIFACTS_DIR" ]; then
    echo "Usage: $0 <version_tag> <artifacts_dir> <output_file> [component_manifests...]" >&2
    exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${ARTIFACTS_DIR}/release-manifest.json"
fi

log_info() {
    echo "[INFO] $1"
}

# Get package info
PACKAGE_HASH=""
PACKAGE_SIZE=0
PACKAGE_NAME=""

# Find the main release package
if [ -f "${ARTIFACTS_DIR}/bllvm-${VERSION_TAG}-linux-x86_64.tar.gz" ]; then
    PACKAGE_NAME="bllvm-${VERSION_TAG}-linux-x86_64.tar.gz"
    PACKAGE_PATH="${ARTIFACTS_DIR}/${PACKAGE_NAME}"
elif [ -f "${ARTIFACTS_DIR}/bllvm-${VERSION_TAG}-windows-x86_64.zip" ]; then
    PACKAGE_NAME="bllvm-${VERSION_TAG}-windows-x86_64.zip"
    PACKAGE_PATH="${ARTIFACTS_DIR}/${PACKAGE_NAME}"
fi

if [ -n "$PACKAGE_NAME" ] && [ -f "$PACKAGE_PATH" ]; then
    if command -v sha256sum &> /dev/null; then
        PACKAGE_HASH=$(sha256sum "$PACKAGE_PATH" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        PACKAGE_HASH=$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')
    fi
    PACKAGE_SIZE=$(stat -f%z "$PACKAGE_PATH" 2>/dev/null || stat -c%s "$PACKAGE_PATH" 2>/dev/null || echo "0")
fi

# Get git commit if available
INTEGRATION_COMMIT=""
if command -v git &> /dev/null && [ -d ".git" ]; then
    INTEGRATION_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
fi

# Build components JSON from manifests
COMPONENTS_JSON="{"
if [ ${#COMPONENT_MANIFESTS[@]} -gt 0 ]; then
    FIRST=true
    for manifest_file in "${COMPONENT_MANIFESTS[@]}"; do
        if [ -f "$manifest_file" ]; then
            if [ "$FIRST" = false ]; then
                COMPONENTS_JSON="${COMPONENTS_JSON},"
            fi
            COMPONENT_NAME=$(jq -r '.component' "$manifest_file")
            COMPONENT_DATA=$(jq -c '{version, commit, source, binary}' "$manifest_file")
            COMPONENTS_JSON="${COMPONENTS_JSON}\"${COMPONENT_NAME}\":${COMPONENT_DATA}"
            FIRST=false
        fi
    done
fi
COMPONENTS_JSON="${COMPONENTS_JSON}}"

# Generate integration manifest
cat > "$OUTPUT_FILE" <<EOF
{
  "bllvm_release": "${VERSION_TAG}",
  "release_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "integration_commit": "${INTEGRATION_COMMIT}",
  "components": ${COMPONENTS_JSON},
  "package": {
    "name": "${PACKAGE_NAME}",
    "hash": "${PACKAGE_HASH}",
    "size": ${PACKAGE_SIZE}
  },
  "verification": {
    "checksums_file": "SHA256SUMS-*",
    "instructions": "Verify checksums: sha256sum -c SHA256SUMS-*"
  }
}
EOF

log_info "Generated integration manifest: $OUTPUT_FILE"

