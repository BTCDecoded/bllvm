#!/bin/bash
#
# Cancel Old Workflow Runs
# Cancels queued workflow runs except the most recent one
#
# Usage: ./cancel-old-jobs.sh [repo] [workflow-name]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ORG="${GITHUB_ORG:-BTCDecoded}"
REPO="${1:-commons}"
WORKFLOW_NAME="${2:-release_orchestrator}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

# Check for token
if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ No GitHub token provided.${NC}"
    echo "   Set GITHUB_TOKEN or GH_TOKEN environment variable"
    exit 1
fi

echo -e "${BLUE}🔍 Canceling old workflow runs for ${ORG}/${REPO}${NC}"
echo "====================================="

# Helper to perform API calls
api_get() {
    local path="$1"
    curl -s -H "Authorization: token $TOKEN" "https://api.github.com/${path}"
}

api_post() {
    local path="$1"
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/${path}")
    echo "$response"
}

# Get all workflow runs
WORKFLOW_RUNS=$(api_get "repos/${ORG}/${REPO}/actions/runs?per_page=20")

# Get the most recent workflow run ID
LATEST_RUN_ID=$(echo "$WORKFLOW_RUNS" | jq -r --arg name "$WORKFLOW_NAME" '.workflow_runs[] | select(.name | contains($name)) | .id' | head -1)

if [ "$LATEST_RUN_ID" = "null" ] || [ -z "$LATEST_RUN_ID" ]; then
    echo -e "${YELLOW}⚠️  No workflow runs found for ${WORKFLOW_NAME}${NC}"
    exit 1
fi

echo -e "${CYAN}📋 Latest workflow run ID: ${LATEST_RUN_ID}${NC}"
echo ""

# Cancel all queued workflow runs except the latest one
echo -e "${BLUE}🔄 Canceling old queued workflow runs...${NC}"
CANCELED_COUNT=0

echo "$WORKFLOW_RUNS" | jq -r --arg name "$WORKFLOW_NAME" --argjson latest "$LATEST_RUN_ID" \
    '.workflow_runs[] | 
    select(.name | contains($name)) | 
    select(.status == "queued") | 
    select(.id != $latest) | 
    "\(.id) \(.name)"' | while read -r run_id name; do
    echo "  Canceling workflow run ${run_id} (${name})..."
    
    RESPONSE=$(api_post "repos/${ORG}/${REPO}/actions/runs/${run_id}/cancel")
    HTTP_CODE="${RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "202" ]; then
        echo -e "    ${GREEN}✅ Successfully canceled run ${run_id}${NC}"
        CANCELED_COUNT=$((CANCELED_COUNT + 1))
    else
        echo -e "    ${RED}❌ Failed to cancel run ${run_id} (HTTP ${HTTP_CODE})${NC}"
    fi
done

echo ""
echo "====================================="
echo -e "${GREEN}📊 Summary:${NC}"
echo "  Latest workflow run ID: ${LATEST_RUN_ID}"
echo "  Workflow runs canceled: ${CANCELED_COUNT}"
echo ""
echo -e "${GREEN}✅ Cancel operation complete${NC}"

