#!/bin/bash
#
# Comprehensive Runner Status Report for BTCDecoded
# Shows runner status, workflow execution, and system resources
#
# Usage: ./runner-status.sh [org]
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
ORG="${1:-${GITHUB_ORG:-BTCDecoded}}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

# Check for token
if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ No GitHub token provided.${NC}"
    echo "   Set GITHUB_TOKEN or GH_TOKEN environment variable"
    echo "   Or use: gh auth login"
    exit 1
fi

# Helper to perform API calls
api_get() {
    local path="$1"
    curl -s -H "Authorization: token $TOKEN" "https://api.github.com/${path}"
}

echo -e "${BLUE}🔍 Comprehensive Runner Status Report${NC}"
echo "====================================="
echo "Timestamp: $(date)"
echo "Organization: ${ORG}"
echo ""

# Check runner status
echo -e "${CYAN}📊 Runner Status:${NC}"
echo "----------------"
RUNNER_INFO=$(api_get "orgs/${ORG}/actions/runners")

if [ "$(echo "$RUNNER_INFO" | jq -r '.total_count // 0')" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No runners found for organization${NC}"
else
    echo "$RUNNER_INFO" | jq -r '.runners[] | {
        name: .name,
        status: .status,
        busy: .busy,
        labels: [.labels[].name] | join(", ")
    } | "  Name: \(.name)\n  Status: \(.status)\n  Busy: \(.busy)\n  Labels: \(.labels)\n"'
fi
echo ""

# Check latest workflow runs across key repositories
echo -e "${CYAN}📋 Latest Workflow Runs:${NC}"
echo "------------------------"
REPOS=("commons" "bllvm-consensus" "bllvm-protocol" "bllvm-node" "bllvm-sdk" "governance-app")

for repo in "${REPOS[@]}"; do
    RUNS=$(api_get "repos/${ORG}/${repo}/actions/runs?per_page=1")
    LATEST_RUN=$(echo "$RUNS" | jq -r '.workflow_runs[0] // empty')
    
    if [ -n "$LATEST_RUN" ] && [ "$LATEST_RUN" != "null" ]; then
        STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
        CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion // "pending"')
        NAME=$(echo "$LATEST_RUN" | jq -r '.name')
        
        case "$CONCLUSION" in
            "success")
                ICON="✅"
                COLOR="$GREEN"
                ;;
            "failure")
                ICON="❌"
                COLOR="$RED"
                ;;
            "cancelled")
                ICON="⏹️"
                COLOR="$YELLOW"
                ;;
            *)
                ICON="🔄"
                COLOR="$BLUE"
                ;;
        esac
        
        echo -e "${COLOR}${ICON} ${repo}: ${NAME} - ${STATUS} (${CONCLUSION})${NC}"
    else
        echo -e "${YELLOW}⚠️  ${repo}: No workflow runs found${NC}"
    fi
done
echo ""

# Check system resources (if on runner host)
if command -v free >/dev/null 2>&1 && command -v df >/dev/null 2>&1; then
    echo -e "${CYAN}💾 System Resources:${NC}"
    echo "-------------------"
    MEMORY=$(free -h | grep Mem | awk '{print "  Memory: " $3 "/" $2 " (" $7 " available)"}')
    DISK=$(df -h / | tail -1 | awk '{print "  Disk: " $3 "/" $2 " (" $4 " available)"}')
    echo "$MEMORY"
    echo "$DISK"
    echo ""
fi

# Check for active/queued workflows
echo -e "${CYAN}🔄 Active/Queued Workflows:${NC}"
echo "---------------------------"
TOTAL_ACTIVE=0
TOTAL_QUEUED=0

for repo in "${REPOS[@]}"; do
    RUNS=$(api_get "repos/${ORG}/${repo}/actions/runs?per_page=5")
    ACTIVE=$(echo "$RUNS" | jq -r '[.workflow_runs[] | select(.status == "in_progress")] | length')
    QUEUED=$(echo "$RUNS" | jq -r '[.workflow_runs[] | select(.status == "queued")] | length')
    
    if [ "$ACTIVE" -gt 0 ] || [ "$QUEUED" -gt 0 ]; then
        echo "  ${repo}: ${ACTIVE} active, ${QUEUED} queued"
        TOTAL_ACTIVE=$((TOTAL_ACTIVE + ACTIVE))
        TOTAL_QUEUED=$((TOTAL_QUEUED + QUEUED))
    fi
done

if [ $TOTAL_ACTIVE -eq 0 ] && [ $TOTAL_QUEUED -eq 0 ]; then
    echo -e "${GREEN}  ✅ No active or queued workflows${NC}"
else
    echo -e "${BLUE}  📊 Total: ${TOTAL_ACTIVE} active, ${TOTAL_QUEUED} queued${NC}"
fi

echo ""
echo "====================================="
echo -e "${GREEN}✅ Status report complete${NC}"

