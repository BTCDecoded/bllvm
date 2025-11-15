#!/bin/bash
#
# Check CI Build Status for BTCDecoded Repositories
# Local-friendly CI status checker that works with or without .env
#
# Usage: ./check-ci-status.sh [repo] [workflow-file]
#

set -euo pipefail

# Default values
ORG="${GITHUB_ORG:-BTCDecoded}"
REPO="${1:-commons}"
WORKFLOW_FILE="${2:-release_orchestrator.yml}"
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

echo "🔍 Checking CI Build Status for ${ORG}/${REPO} (${WORKFLOW_FILE})"
echo "====================================="

# Helper to perform API calls via curl or gh
gh_available=false
if command -v gh >/dev/null 2>&1; then
    if gh auth status -h github.com >/dev/null 2>&1; then
        gh_available=true
    fi
fi

api_get() {
    local path="$1"
    if [ -n "$TOKEN" ]; then
        curl -s -H "Authorization: token $TOKEN" "https://api.github.com/${path}"
    elif [ "$gh_available" = true ]; then
        gh api "$path"
    else
        echo "❌ No credentials available. Export GH_TOKEN/GITHUB_TOKEN or login via 'gh auth login'" >&2
        exit 1
    fi
}

# Get the latest run for the specific workflow file
RUNS_JSON=$(api_get "repos/${ORG}/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=1")
LATEST_RUN=$(echo "$RUNS_JSON" | jq -r '.workflow_runs[0].id // empty')

if [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
    echo "❌ No workflow runs found (or insufficient permissions)"
    exit 1
fi

echo "📋 Latest Workflow Run ID: $LATEST_RUN"

# Get workflow details
WORKFLOW_INFO=$(api_get "repos/${ORG}/${REPO}/actions/runs/${LATEST_RUN}")

WORKFLOW_NAME=$(echo "$WORKFLOW_INFO" | jq -r '.name')
WORKFLOW_STATUS=$(echo "$WORKFLOW_INFO" | jq -r '.status')
WORKFLOW_CONCLUSION=$(echo "$WORKFLOW_INFO" | jq -r '.conclusion // "pending"')
WORKFLOW_URL=$(echo "$WORKFLOW_INFO" | jq -r '.html_url')

echo "📋 Workflow: $WORKFLOW_NAME (ID: $LATEST_RUN)"
echo "📊 Status: $WORKFLOW_STATUS, Conclusion: $WORKFLOW_CONCLUSION"
echo "🔗 URL: $WORKFLOW_URL"

# Get jobs for this workflow
JOBS=$(api_get "repos/${ORG}/${REPO}/actions/runs/${LATEST_RUN}/jobs")

echo ""
echo "🔧 Jobs:"
echo "====================================="
echo "$JOBS" | jq -r '.jobs[] | "  \(.name): \(.status) (\(.conclusion // "pending"))"' | head -20

echo ""
echo "====================================="
echo "✅ CI Status check complete"

