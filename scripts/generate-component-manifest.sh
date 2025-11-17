#!/bin/bash
#
# Generate build manifest for a component repository
#
# Usage: generate-component-manifest.sh <repo> <version_tag> <commit_hash> <platform> <output_file> [--artifacts-dir DIR]
#

set -euo pipefail

REPO="${1:-}"
VERSION_TAG="${2:-}"
COMMIT_HASH="${3:-}"
PLATFORM="${4:-linux-x86_64}"
OUTPUT_FILE="${5:-}"
ARTIFACTS_DIR=""

# Parse optional arguments
shift 5 || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --artifacts-dir)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$REPO" ] || [ -z "$VERSION_TAG" ] || [ -z "$COMMIT_HASH" ]; then
    echo "Usage: $0 <repo> <version_tag> <commit_hash> <platform> <output_file> [--artifacts-dir DIR]" >&2
    exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="component-manifest-${REPO}-${VERSION_TAG}.json"
fi

# Default artifacts dir to current directory if not specified
if [ -z "$ARTIFACTS_DIR" ]; then
    ARTIFACTS_DIR="."
fi

# Get binary hash if available
BINARY_HASH=""
BINARY_SIZE=0
BINARY_NAME=""

if [[ "$PLATFORM" == *"windows"* ]]; then
    BINARIES_DIR="${ARTIFACTS_DIR}/binaries-windows"
else
    BINARIES_DIR="${ARTIFACTS_DIR}/binaries"
fi

# Try to find the main binary for this repo
case "$REPO" in
    bllvm)
        BINARY_NAME="bllvm"
        ;;
    bllvm-sdk)
        BINARY_NAME="bllvm-keygen"  # Use first binary as representative
        ;;
    governance-app)
        BINARY_NAME="governance-app"
        ;;
    bllvm-node)
        BINARY_NAME="bllvm-node"
        ;;
    *)
        # For libraries, no binary
        BINARY_NAME=""
        ;;
esac

if [ -n "$BINARY_NAME" ]; then
    BINARY_PATH="${BINARIES_DIR}/${BINARY_NAME}"
    if [[ "$PLATFORM" == *"windows"* ]]; then
        BINARY_PATH="${BINARY_PATH}.exe"
    fi
    
    if [ -f "$BINARY_PATH" ]; then
        if command -v sha256sum &> /dev/null; then
            BINARY_HASH=$(sha256sum "$BINARY_PATH" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            BINARY_HASH=$(shasum -a 256 "$BINARY_PATH" | awk '{print $1}')
        fi
        BINARY_SIZE=$(stat -f%z "$BINARY_PATH" 2>/dev/null || stat -c%s "$BINARY_PATH" 2>/dev/null || echo "0")
    else
        # Try to find any binary from this repo
        if [ -d "$BINARIES_DIR" ]; then
            FOUND_BINARY=$(find "$BINARIES_DIR" -type f -name "${BINARY_NAME}*" 2>/dev/null | head -1)
            if [ -n "$FOUND_BINARY" ] && [ -f "$FOUND_BINARY" ]; then
                if command -v sha256sum &> /dev/null; then
                    BINARY_HASH=$(sha256sum "$FOUND_BINARY" | awk '{print $1}')
                elif command -v shasum &> /dev/null; then
                    BINARY_HASH=$(shasum -a 256 "$FOUND_BINARY" | awk '{print $1}')
                fi
                BINARY_SIZE=$(stat -f%z "$FOUND_BINARY" 2>/dev/null || stat -c%s "$FOUND_BINARY" 2>/dev/null || echo "0")
                BINARY_NAME=$(basename "$FOUND_BINARY")
            fi
        fi
    fi
fi

# Generate manifest
cat > "$OUTPUT_FILE" <<EOF
{
  "component": "${REPO}",
  "version": "${VERSION_TAG}",
  "commit": "${COMMIT_HASH}",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "${PLATFORM}",
  "source": {
    "repo": "BTCDecoded/${REPO}",
    "tag": "${VERSION_TAG}",
    "commit": "${COMMIT_HASH}",
    "url": "https://github.com/BTCDecoded/${REPO}/releases/tag/${VERSION_TAG}"
  },
  "binary": {
    "name": "${BINARY_NAME}",
    "hash": "${BINARY_HASH}",
    "size": ${BINARY_SIZE}
  },
  "reproducible": false,
  "build_method": "github-actions"
}
EOF

echo "Generated component manifest: $OUTPUT_FILE"

