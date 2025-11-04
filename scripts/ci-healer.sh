#!/bin/bash
#
# CI/CD Auto-Healer for BTCDecoded
# Monitors CI/CD pipelines and automatically fixes common issues
#
# Usage: ./ci-healer.sh [options]
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
REPO="${CI_REPO:-commons}"
WORKFLOW_FILE="${CI_WORKFLOW:-release_orchestrator.yml}"
GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
INTERVAL=120  # Check every 2 minutes
LOG_FILE="${CI_HEALER_LOG:-ci-healer.log}"
AUTO_FIX=true
MAX_RETRIES=3
RETRY_DELAY=30

# Function to show usage
show_usage() {
    cat << EOF
CI/CD Auto-Healer for BTCDecoded

Usage: $0 [options]

Options:
    -h, --help              Show this help message
    -t, --token TOKEN       GitHub token (default: from GITHUB_TOKEN env var)
    -r, --repo REPO         GitHub repository (default: commons)
    -w, --workflow FILE     Workflow file name (default: release_orchestrator.yml)
    -i, --interval SECONDS  Check interval in seconds (default: 120)
    -l, --log-file FILE     Log file path (default: ci-healer.log)
    --no-auto-fix           Don't automatically fix issues (monitor only)
    --max-retries N         Maximum retry attempts (default: 3)
    --retry-delay SECONDS   Delay between retries (default: 30)

Examples:
    $0                      # Auto-heal with default settings
    $0 -i 60                # Check every 60 seconds
    $0 --no-auto-fix        # Monitor only, don't fix
    $0 -r consensus-proof   # Monitor consensus-proof repository

EOF
}

# Function to log messages
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "${RED}[$timestamp] ERROR: $message${NC}" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] WARNING: $message${NC}" | tee -a "$LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[$timestamp] INFO: $message${NC}" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] SUCCESS: $message${NC}" | tee -a "$LOG_FILE"
            ;;
        "HEAL")
            echo -e "${CYAN}[$timestamp] HEAL: $message${NC}" | tee -a "$LOG_FILE"
            ;;
        *)
            echo "[$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Function to validate GitHub token
validate_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log "ERROR" "GitHub token not found. Set GITHUB_TOKEN environment variable or use --token option."
        exit 1
    fi
    
    # Test token validity
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/user" | jq -r '.login // empty' 2>/dev/null)
    
    if [ -z "$response" ]; then
        log "ERROR" "Invalid GitHub token. Please check your token."
        exit 1
    fi
    
    log "INFO" "Using GitHub token for user: $response"
}

# Function to get latest workflow run
get_latest_workflow_run() {
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${ORG}/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=1" | \
        jq -r '.workflow_runs[0]')
    
    if [ "$response" = "null" ] || [ -z "$response" ]; then
        log "ERROR" "No workflow runs found for ${WORKFLOW_FILE}"
        return 1
    fi
    
    echo "$response"
}

# Function to get job status
get_job_status() {
    local run_id=$1
    
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${ORG}/${REPO}/actions/runs/$run_id/jobs" | \
        jq -r '.jobs[] | "\(.name): \(.status) (\(.conclusion // "pending"))"')
    
    if [ "$response" = "null" ] || [ -z "$response" ]; then
        log "WARNING" "No jobs found for workflow run ID: $run_id"
        return 1
    fi
    
    echo "$response"
}

# Function to retry failed workflow
retry_workflow() {
    local run_id=$1
    
    log "HEAL" "Retrying failed workflow run: $run_id"
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${ORG}/${REPO}/actions/runs/$run_id/retry")
    
    local http_code="${response: -3}"
    if [ "$http_code" = "204" ] || [ "$http_code" = "201" ]; then
        log "SUCCESS" "Successfully retried workflow run: $run_id"
        return 0
    else
        log "ERROR" "Failed to retry workflow run: $run_id (HTTP $http_code)"
        return 1
    fi
}

# Function to analyze and fix issues
analyze_and_fix() {
    local run_id=$1
    local job_status=$(get_job_status "$run_id")
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Could not get job status for analysis"
        return 1
    fi
    
    # Check for failed jobs
    local failed_jobs=$(echo "$job_status" | grep "failure" || true)
    if [ -n "$failed_jobs" ]; then
        log "WARNING" "Failed jobs detected:"
        echo "$failed_jobs" | while IFS=':' read -r job_name rest; do
            log "WARNING" "  ❌ $job_name"
        done
        
        # Try to retry the workflow if auto-fix is enabled
        if [ "$AUTO_FIX" = true ]; then
            log "HEAL" "Attempting to retry failed workflow..."
            if retry_workflow "$run_id"; then
                log "SUCCESS" "Workflow retry initiated"
                return 0
            else
                log "ERROR" "Failed to retry workflow"
                return 1
            fi
        fi
        
        return 1
    else
        log "SUCCESS" "No failed jobs detected"
        return 0
    fi
}

# Function to check for stuck workflows
check_stuck_workflows() {
    log "INFO" "Checking for stuck workflows..."
    
    # Get workflows that have been running for more than 30 minutes
    local stuck_workflows=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${ORG}/${REPO}/actions/runs?per_page=10" | \
        jq -r --argjson now "$(date +%s)" '.workflow_runs[] | 
            select(.status == "in_progress") | 
            select(($now - (.created_at | fromdateiso8601)) > 1800) | 
            "\(.id): \(.name)"')
    
    if [ -n "$stuck_workflows" ]; then
        log "WARNING" "Stuck workflows detected:"
        echo "$stuck_workflows" | while IFS=':' read -r run_id workflow_name; do
            log "WARNING" "  🔄 $workflow_name (ID: $run_id) - running for >30 minutes"
        done
    else
        log "INFO" "No stuck workflows detected"
    fi
}

# Function to display current status
display_status() {
    local run_info=$(get_latest_workflow_run)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local run_id=$(echo "$run_info" | jq -r '.id')
    local workflow_name=$(echo "$run_info" | jq -r '.name')
    local status=$(echo "$run_info" | jq -r '.status')
    local conclusion=$(echo "$run_info" | jq -r '.conclusion // "pending"')
    
    echo "🔍 CI/CD Auto-Healer - $(date)"
    echo "====================================="
    echo "📋 Repository: ${ORG}/${REPO}"
    echo "📋 Workflow: $workflow_name"
    echo "📋 Run ID: $run_id"
    echo "📊 Status: $status ($conclusion)"
    echo "🔧 Auto-Fix: $([ "$AUTO_FIX" = true ] && echo "ENABLED" || echo "DISABLED")"
    echo ""
    
    # Analyze and fix issues
    if analyze_and_fix "$run_id"; then
        log "SUCCESS" "CI/CD Pipeline is healthy"
    else
        log "WARNING" "CI/CD Pipeline has issues"
    fi
    
    # Check for stuck workflows
    check_stuck_workflows
    
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -w|--workflow)
            WORKFLOW_FILE="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --no-auto-fix)
            AUTO_FIX=false
            shift
            ;;
        --max-retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --retry-delay)
            RETRY_DELAY="$2"
            shift 2
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate token
validate_token

# Initialize log file
log "INFO" "Starting CI/CD Auto-Healer"
log "INFO" "Repository: ${ORG}/${REPO}"
log "INFO" "Workflow: ${WORKFLOW_FILE}"
log "INFO" "Check interval: ${INTERVAL}s"
log "INFO" "Log file: $LOG_FILE"
log "INFO" "Auto-fix: $([ "$AUTO_FIX" = true ] && echo "ENABLED" || echo "DISABLED")"

# Main monitoring loop
while true; do
    clear
    echo "🔄 CI/CD Auto-Healer - $(date)"
    echo "====================================="
    echo "Press Ctrl+C to stop"
    echo ""
    
    display_status
    
    echo "⏰ Next check in ${INTERVAL} seconds..."
    sleep "$INTERVAL"
done

