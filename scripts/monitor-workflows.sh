#!/bin/bash
#
# Monitor BTCDecoded Workflows
# Monitors workflow execution across BTCDecoded repositories
#
# Usage: ./monitor-workflows.sh [repo] [workflow-file]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ORG="${GITHUB_ORG:-BTCDecoded}"
REPO="${1:-commons}"
WORKFLOW_FILE="${2:-release_orchestrator.yml}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

# Check for token
if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ No GitHub token provided.${NC}"
    echo "   Set GITHUB_TOKEN or GH_TOKEN environment variable"
    echo "   Or use: gh auth login"
    exit 1
fi

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
        echo -e "${RED}❌ No credentials available.${NC}" >&2
        exit 1
    fi
}

echo -e "${BLUE}🔍 Monitoring workflows for ${ORG}/${REPO}${NC}"
echo "====================================="
echo ""

# Get the latest run for the specific workflow file
RUNS_JSON=$(api_get "repos/${ORG}/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=5")
LATEST_RUN=$(echo "$RUNS_JSON" | jq -r '.workflow_runs[0].id // empty')

if [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
    echo -e "${RED}❌ No workflow runs found for ${WORKFLOW_FILE}${NC}"
    exit 1
fi

echo -e "${CYAN}📋 Latest Workflow Run ID: ${LATEST_RUN}${NC}"

# Get workflow details
WORKFLOW_INFO=$(api_get "repos/${ORG}/${REPO}/actions/runs/${LATEST_RUN}")

WORKFLOW_NAME=$(echo "$WORKFLOW_INFO" | jq -r '.name')
WORKFLOW_STATUS=$(echo "$WORKFLOW_INFO" | jq -r '.status')
WORKFLOW_CONCLUSION=$(echo "$WORKFLOW_INFO" | jq -r '.conclusion // "pending"')
WORKFLOW_URL=$(echo "$WORKFLOW_INFO" | jq -r '.html_url')

echo -e "${CYAN}📋 Workflow: ${WORKFLOW_NAME} (ID: ${LATEST_RUN})${NC}"
echo -e "${CYAN}📊 Status: ${WORKFLOW_STATUS}, Conclusion: ${WORKFLOW_CONCLUSION}${NC}"
echo -e "${CYAN}🔗 URL: ${WORKFLOW_URL}${NC}"

# Get jobs for this workflow
JOBS=$(api_get "repos/${ORG}/${REPO}/actions/runs/${LATEST_RUN}/jobs")

echo ""
echo "🔧 Jobs:"
echo "====================================="
echo "$JOBS" | jq -r '.jobs[] | {
    name: .name,
    status: .status,
    conclusion: .conclusion // "pending",
    runner: .runner_name // "none"
} | "\(.name): \(.status) (\(.conclusion)) - Runner: \(.runner)"' | while IFS=':' read -r job_name rest; do
    status=$(echo "$rest" | grep -oE '(completed|in_progress|queued|waiting)')
    conclusion=$(echo "$rest" | grep -oE '(success|failure|cancelled|pending)')
    
    case "$status" in
        "completed")
            if [ "$conclusion" = "success" ]; then
                echo -e "${GREEN}✅ ${job_name}: ${status} (${conclusion})${NC}"
            else
                echo -e "${RED}❌ ${job_name}: ${status} (${conclusion})${NC}"
            fi
            ;;
        "in_progress")
            echo -e "${BLUE}🔄 ${job_name}: ${status}${NC}"
            ;;
        "queued"|"waiting")
            echo -e "${YELLOW}⏳ ${job_name}: ${status}${NC}"
            ;;
        *)
            echo -e "${YELLOW}❓ ${job_name}: ${status}${NC}"
            ;;
    esac
done

echo ""
echo "====================================="
echo -e "${GREEN}✅ Workflow monitoring complete${NC}"

