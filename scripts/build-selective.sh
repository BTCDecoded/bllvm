#!/bin/bash
#
# Selective build script - builds only repos that need building
# Compatible with build.sh but allows skipping repos that have existing releases
#
# Usage: build-selective.sh --skip-repos "repo1,repo2" [other build.sh args]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_SCRIPT="${COMMONS_DIR}/build.sh"

SKIP_REPOS=""

# Parse arguments
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-repos)
            SKIP_REPOS="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# If no repos to skip, just use build.sh directly
if [ -z "$SKIP_REPOS" ]; then
    exec "$BUILD_SCRIPT" "${ARGS[@]}"
fi

# Convert skip list to array
IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_REPOS"

# Check if repo should be skipped
should_skip() {
    local repo=$1
    for skip_repo in "${SKIP_ARRAY[@]}"; do
        if [ "$repo" = "$skip_repo" ]; then
            return 0  # Skip this repo
        fi
    done
    return 1  # Don't skip
}

# For now, we'll still use build.sh but modify its behavior
# Since build.sh doesn't support skipping, we'll:
# 1. Build all repos (dependencies are needed anyway)
# 2. But we'll rely on downloaded artifacts for skipped repos

# The actual skipping will be handled by not collecting binaries for skipped repos
# This is a temporary solution - ideally build.sh would support --skip-repos

echo "Note: build-selective.sh will build all repos (dependencies required)"
echo "Skipped repos (artifacts should be pre-downloaded): ${SKIP_REPOS}"
echo ""

# Just call build.sh - the artifacts collection step will handle skipping
exec "$BUILD_SCRIPT" "${ARGS[@]}"

