#!/bin/bash
#
# Determine which repositories need to be built vs which can use existing releases
# Based on versions.toml and checking GitHub releases
#
# Usage: determine-build-requirements.sh [versions.toml] [platform]
# Outputs: JSON with build requirements per repo
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${1:-${COMMONS_DIR}/versions.toml}"
PLATFORM="${2:-linux-x86_64}"
ORG="${GITHUB_ORG:-BTCDecoded}"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: versions.toml not found: $VERSIONS_FILE" >&2
    exit 1
fi

# Get token from environment
TOKEN="${GITHUB_TOKEN:-${REPO_ACCESS_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
    echo "Error: GITHUB_TOKEN or REPO_ACCESS_TOKEN required" >&2
    exit 1
fi

log_info() {
    echo "[INFO] $1" >&2
}

# Repos that produce binaries (need artifacts)
BINARY_REPOS=("bllvm" "bllvm-sdk" "governance-app" "bllvm-node")

# Repos that are libraries only (don't need artifacts, but need to be built for dependencies)
LIBRARY_REPOS=("bllvm-consensus" "bllvm-protocol")

# Parse versions.toml and check each repo
BUILD_REQUIREMENTS="{"

# Check each repo
for repo in "${BINARY_REPOS[@]}" "${LIBRARY_REPOS[@]}"; do
    # Extract version tag from versions.toml
    # Format: repo-name = { version = "...", git_tag = "...", ... }
    VERSION_TAG=$(grep -E "^${repo}" "$VERSIONS_FILE" | sed -n 's/.*git_tag = "\([^"]*\)".*/\1/p' || echo "")
    
    if [ -z "$VERSION_TAG" ]; then
        log_info "No version found for ${repo}, skipping..."
        continue
    fi
    
    log_info "Checking ${repo}@${VERSION_TAG}..."
    
    # Check if release exists
    if "$SCRIPT_DIR/check-release-exists.sh" "$repo" "$VERSION_TAG" "$ORG" >/dev/null 2>&1; then
        # Release exists - can download artifacts
        log_info "✅ Release exists for ${repo}@${VERSION_TAG} - will download artifacts"
        BUILD_REQUIREMENTS="${BUILD_REQUIREMENTS}\"${repo}\":{\"build\":false,\"version\":\"${VERSION_TAG}\",\"download\":true},"
    else
        # Release doesn't exist - need to build
        log_info "❌ No release found for ${repo}@${VERSION_TAG} - will build"
        BUILD_REQUIREMENTS="${BUILD_REQUIREMENTS}\"${repo}\":{\"build\":true,\"version\":\"${VERSION_TAG}\",\"download\":false},"
    fi
done

# Remove trailing comma and close JSON
BUILD_REQUIREMENTS="${BUILD_REQUIREMENTS%,}}"

# Output JSON
echo "$BUILD_REQUIREMENTS" | jq '.'

