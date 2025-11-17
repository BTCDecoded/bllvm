#!/bin/bash
#
# Check if a GitHub release exists for a repository at a specific version
#
# Usage: check-release-exists.sh <repo> <version_tag> [org]
# Returns: 0 if release exists, 1 if not, 2 on error
#

set -euo pipefail

REPO="${1:-}"
VERSION_TAG="${2:-}"
ORG="${3:-BTCDecoded}"

if [ -z "$REPO" ] || [ -z "$VERSION_TAG" ]; then
    echo "Usage: $0 <repo> <version_tag> [org]" >&2
    exit 2
fi

# Get token from environment
TOKEN="${GITHUB_TOKEN:-${REPO_ACCESS_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
    echo "Error: GITHUB_TOKEN or REPO_ACCESS_TOKEN required" >&2
    exit 2
fi

# Check if release exists using GitHub API
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${ORG}/${REPO}/releases/tags/${VERSION_TAG}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    # Release exists
    RELEASE_ID=$(echo "$BODY" | jq -r '.id // empty')
    if [ -n "$RELEASE_ID" ] && [ "$RELEASE_ID" != "null" ]; then
        echo "$RELEASE_ID"
        exit 0
    fi
elif [ "$HTTP_CODE" = "404" ]; then
    # Release doesn't exist
    exit 1
else
    # Error
    echo "Error: GitHub API returned HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 2
fi

