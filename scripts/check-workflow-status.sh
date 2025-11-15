#!/bin/bash
# Check workflow run status and wait for completion
# Polls GitHub Actions API until workflows complete or timeout

set -euo pipefail

# Configuration
ORG="${GITHUB_ORG:-BTCDecoded}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
REPOS=("bllvm-consensus" "bllvm-protocol" "bllvm-node" "bllvm-sdk")
TIMEOUT="${TIMEOUT:-300}"  # Default 5 minutes
POLL_INTERVAL="${POLL_INTERVAL:-10}"  # Check every 10 seconds
MAX_RUNS="${MAX_RUNS:-1}"  # Check the most recent run

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_status() {
    echo -e "${CYAN}→${NC} $1"
}

# Helper to perform API calls via curl or gh
gh_available=false
if command -v gh >/dev/null 2>&1; then
    if gh auth status -h github.com >/dev/null 2>&1; then
        gh_available=true
    fi
fi

api_request() {
    local url="$1"
    # If URL doesn't start with http, prepend API base URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://api.github.com/${url#/}"
    fi
    if [ -n "$TOKEN" ]; then
        curl -s -H "Authorization: token ${TOKEN}" \
             -H "Accept: application/vnd.github.v3+json" \
             "$url"
    elif [ "$gh_available" = true ]; then
        # Remove base URL for gh CLI (it expects relative paths)
        local gh_url="${url#https://api.github.com/}"
        gh api "$gh_url"
    else
        print_error "No credentials available. Export GITHUB_TOKEN/GH_TOKEN or login via 'gh auth login'"
        exit 1
    fi
}

# Get the most recent workflow run for a repository
get_latest_run() {
    local repo="$1"
    local url="repos/${ORG}/${repo}/actions/runs?per_page=1"
    
    local response=$(api_request "$url")
    echo "$response" | jq -r '.workflow_runs[0] // empty'
}

# Check if a run is completed
is_run_completed() {
    local run_json="$1"
    local status=$(echo "$run_json" | jq -r '.status')
    [ "$status" = "completed" ]
}

# Get run status info
get_run_info() {
    local run_json="$1"
    local run_id=$(echo "$run_json" | jq -r '.id')
    local run_number=$(echo "$run_json" | jq -r '.run_number')
    local status=$(echo "$run_json" | jq -r '.status')
    local conclusion=$(echo "$run_json" | jq -r '.conclusion // "null"')
    local workflow_name=$(echo "$run_json" | jq -r '.name')
    local created_at=$(echo "$run_json" | jq -r '.created_at')
    local updated_at=$(echo "$run_json" | jq -r '.updated_at')
    
    echo "$run_id|$run_number|$status|$conclusion|$workflow_name|$created_at|$updated_at"
}

# Wait for workflow to complete
wait_for_completion() {
    local repo="$1"
    local start_time=$(date +%s)
    local elapsed=0
    
    print_info "Waiting for ${repo} workflow to complete..."
    print_info "Timeout: ${TIMEOUT}s, Poll interval: ${POLL_INTERVAL}s"
    
    while [ $elapsed -lt $TIMEOUT ]; do
        local run_json=$(get_latest_run "$repo")
        
        if [ -z "$run_json" ] || [ "$run_json" = "null" ]; then
            print_warning "No workflow runs found for ${repo}"
            sleep "$POLL_INTERVAL"
            elapsed=$(($(date +%s) - start_time))
            continue
        fi
        
        local info=$(get_run_info "$run_json")
        IFS='|' read -r run_id run_number status conclusion workflow_name created_at updated_at <<< "$info"
        
        print_status "${repo} (#${run_number}): ${status}"
        if [ "$conclusion" != "null" ] && [ "$conclusion" != "" ]; then
            print_status "  Conclusion: ${conclusion}"
        fi
        
        if is_run_completed "$run_json"; then
            local final_conclusion=$(echo "$run_json" | jq -r '.conclusion // "null"')
            print_success "Workflow completed for ${repo} (run #${run_number})"
            if [ "$final_conclusion" != "null" ] && [ "$final_conclusion" != "" ]; then
                if [ "$final_conclusion" = "success" ]; then
                    print_success "  Conclusion: ${final_conclusion}"
                else
                    print_warning "  Conclusion: ${final_conclusion}"
                fi
            fi
            echo "$run_json"
            return 0
        fi
        
        sleep "$POLL_INTERVAL"
        elapsed=$(($(date +%s) - start_time))
        print_info "  Elapsed: ${elapsed}s / ${TIMEOUT}s"
    done
    
    print_error "Timeout waiting for ${repo} workflow to complete"
    return 1
}

# Check all repositories
check_all_repos() {
    local all_completed=true
    
    for repo in "${REPOS[@]}"; do
        echo ""
        print_info "=== Checking ${repo} ==="
        
        if wait_for_completion "$repo"; then
            print_success "${repo} workflow completed"
        else
            print_error "${repo} workflow did not complete in time"
            all_completed=false
        fi
    done
    
    if [ "$all_completed" = true ]; then
        echo ""
        print_success "All workflows completed!"
        return 0
    else
        echo ""
        print_warning "Some workflows did not complete in time"
        return 1
    fi
}

# Main execution
main() {
    print_info "GitHub Workflow Status Checker"
    print_info "Organization: ${ORG}"
    print_info "Repositories: ${REPOS[*]}"
    print_info "Timeout: ${TIMEOUT}s"
    print_info "Poll interval: ${POLL_INTERVAL}s"
    echo ""
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed. Please install curl first."
        exit 1
    fi
    
    # Check for token
    if [ -z "$TOKEN" ] && [ "$gh_available" = false ]; then
        print_error "No GitHub token provided."
        echo "   Set GITHUB_TOKEN or GH_TOKEN environment variable"
        echo "   Or use: gh auth login"
        exit 1
    fi
    
    # Test API token
    print_info "Testing GitHub API authentication..."
    local test_response=$(api_request "https://api.github.com/user")
    if echo "$test_response" | jq -e '.message' > /dev/null 2>&1; then
        print_error "Authentication failed: $(echo "$test_response" | jq -r '.message')"
        exit 1
    fi
    local username=$(echo "$test_response" | jq -r '.login')
    print_success "Authenticated as ${username}"
    echo ""
    
    # Check all repositories
    check_all_repos
}

main "$@"

