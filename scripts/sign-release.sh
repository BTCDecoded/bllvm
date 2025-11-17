#!/bin/bash
#
# Sign Release Script
#
# Signs binaries, SHA256SUMS, and verification bundles for a release.
# Collects signatures from multiple maintainers and aggregates them.
#
# Usage:
#   sign-release.sh --version v0.1.0 --commit abc123 [--key maintainer-key.json] [--threshold 6-of-7]
#
# Environment variables:
#   BLLVM_RELEASE_VERSION - Version string
#   BLLVM_RELEASE_COMMIT - Git commit hash
#   BLLVM_SIGN_KEY - Path to maintainer key file
#   BLLVM_SIGN_THRESHOLD - Signature threshold (e.g., "6-of-7")
#   BLLVM_MAINTAINER_KEYS - Comma-separated list of maintainer public key files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${REPO_ROOT}/artifacts"
SIGNATURES_DIR="${ARTIFACTS_DIR}/signatures"

# Defaults
VERSION="${BLLVM_RELEASE_VERSION:-}"
COMMIT="${BLLVM_RELEASE_COMMIT:-}"
SIGN_KEY="${BLLVM_SIGN_KEY:-}"
THRESHOLD="${BLLVM_SIGN_THRESHOLD:-6-of-7}"
BINARY_TYPE="application"

print_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Sign binaries, SHA256SUMS, and verification bundles for a release.

Options:
  --version VERSION     Release version (e.g., v0.1.0)
  --commit COMMIT      Git commit hash
  --key KEYFILE        Path to maintainer key file
  --threshold THRESHOLD Signature threshold (e.g., "6-of-7")
  --binary-type TYPE   Binary type (consensus, protocol, application)
  --help               Show this help message

Environment variables:
  BLLVM_RELEASE_VERSION - Release version
  BLLVM_RELEASE_COMMIT - Git commit hash
  BLLVM_SIGN_KEY - Path to maintainer key file
  BLLVM_SIGN_THRESHOLD - Signature threshold
  BLLVM_MAINTAINER_KEYS - Comma-separated list of maintainer public key files

Examples:
  # Sign with environment variables
  export BLLVM_RELEASE_VERSION=v0.1.0
  export BLLVM_RELEASE_COMMIT=abc123
  export BLLVM_SIGN_KEY=./maintainer-key.json
  ./sign-release.sh

  # Sign with command-line arguments
  ./sign-release.sh --version v0.1.0 --commit abc123 --key ./maintainer-key.json
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --commit)
            COMMIT="$2"
            shift 2
            ;;
        --key)
            SIGN_KEY="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --binary-type)
            BINARY_TYPE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$VERSION" ]]; then
    echo "Error: --version or BLLVM_RELEASE_VERSION required" >&2
    exit 1
fi

if [[ -z "$COMMIT" ]]; then
    echo "Error: --commit or BLLVM_RELEASE_COMMIT required" >&2
    exit 1
fi

if [[ -z "$SIGN_KEY" ]]; then
    echo "Warning: --key or BLLVM_SIGN_KEY not set, skipping signing" >&2
    echo "Note: This script will create signature files but won't sign them" >&2
fi

# Create signatures directory
mkdir -p "${SIGNATURES_DIR}"

echo "=== Signing Release ==="
echo "Version: ${VERSION}"
echo "Commit: ${COMMIT}"
echo "Threshold: ${THRESHOLD}"
echo "Binary Type: ${BINARY_TYPE}"
echo ""

# Sign binaries
if [[ -d "${ARTIFACTS_DIR}/binaries" ]]; then
    echo "=== Signing Binaries ==="
    for binary in "${ARTIFACTS_DIR}"/binaries/*; do
        if [[ -f "$binary" && -x "$binary" ]]; then
            binary_name=$(basename "$binary")
            sig_file="${SIGNATURES_DIR}/${binary_name}.sig"
            
            if [[ -n "$SIGN_KEY" ]] && command -v bllvm-sign-binary >/dev/null 2>&1; then
                echo "Signing: ${binary_name}"
                bllvm-sign-binary binary \
                    --file "$binary" \
                    --binary-type "$BINARY_TYPE" \
                    --version "$VERSION" \
                    --commit "$COMMIT" \
                    --key "$SIGN_KEY" \
                    --output "$sig_file" || {
                    echo "Warning: Failed to sign ${binary_name}" >&2
                }
            else
                echo "Skipping: ${binary_name} (no key or bllvm-sign-binary not found)"
            fi
        fi
    done
fi

# Sign SHA256SUMS
if [[ -f "${ARTIFACTS_DIR}/SHA256SUMS" ]]; then
    echo ""
    echo "=== Signing SHA256SUMS ==="
    sig_file="${SIGNATURES_DIR}/SHA256SUMS.sig"
    
    if [[ -n "$SIGN_KEY" ]] && command -v bllvm-sign-binary >/dev/null 2>&1; then
        bllvm-sign-binary checksums \
            --file "${ARTIFACTS_DIR}/SHA256SUMS" \
            --version "$VERSION" \
            --key "$SIGN_KEY" \
            --output "$sig_file" || {
            echo "Warning: Failed to sign SHA256SUMS" >&2
        }
    else
        echo "Skipping SHA256SUMS (no key or bllvm-sign-binary not found)"
    fi
fi

# Sign verification bundles
if [[ -d "${ARTIFACTS_DIR}" ]]; then
    echo ""
    echo "=== Signing Verification Bundles ==="
    for bundle in "${ARTIFACTS_DIR}"/verify-artifacts*.tar.gz; do
        if [[ -f "$bundle" ]]; then
            bundle_name=$(basename "$bundle")
            sig_file="${SIGNATURES_DIR}/${bundle_name}.sig"
            
            # Get source hash from git if available
            SOURCE_HASH=""
            if command -v git >/dev/null 2>&1; then
                SOURCE_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")
            fi
            
            if [[ -n "$SIGN_KEY" ]] && command -v bllvm-sign-binary >/dev/null 2>&1; then
                echo "Signing: ${bundle_name}"
                bllvm-sign-binary bundle \
                    --file "$bundle" \
                    --source-hash "${SOURCE_HASH}" \
                    --key "$SIGN_KEY" \
                    --output "$sig_file" || {
                    echo "Warning: Failed to sign ${bundle_name}" >&2
                }
            else
                echo "Skipping: ${bundle_name} (no key or bllvm-sign-binary not found)"
            fi
        fi
    done
fi

# Aggregate signatures if multiple maintainers signed
if [[ -n "${BLLVM_MAINTAINER_KEYS:-}" ]] && command -v bllvm-aggregate-signatures >/dev/null 2>&1; then
    echo ""
    echo "=== Aggregating Signatures ==="
    
    # Find all signature files
    sig_files=$(find "${SIGNATURES_DIR}" -name "*.sig" | tr '\n' ',')
    if [[ -n "$sig_files" ]]; then
        sig_files="${sig_files%,}" # Remove trailing comma
        
        # Aggregate each type of signature
        for sig_type in "binary" "checksums" "bundle"; do
            type_sigs=$(find "${SIGNATURES_DIR}" -name "*${sig_type}*.sig" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$type_sigs" ]]; then
                aggregated="${SIGNATURES_DIR}/${sig_type}-signatures-aggregated.json"
                bllvm-aggregate-signatures \
                    --signatures "$type_sigs" \
                    --threshold "$THRESHOLD" \
                    --pubkeys "${BLLVM_MAINTAINER_KEYS}" \
                    --output "$aggregated" || {
                    echo "Warning: Failed to aggregate ${sig_type} signatures" >&2
                }
            fi
        done
    fi
fi

echo ""
echo "=== Signing Complete ==="
echo "Signatures saved to: ${SIGNATURES_DIR}"
echo ""
echo "Next steps:"
echo "1. Collect signatures from other maintainers"
echo "2. Aggregate signatures: bllvm-aggregate-signatures --signatures sig1.json,sig2.json,... --threshold ${THRESHOLD}"
echo "3. Verify signatures: bllvm-verify-binary ... --signatures aggregated.json --threshold ${THRESHOLD}"

