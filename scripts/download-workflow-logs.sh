#!/bin/bash
# Download workflow logs from GitHub Actions using the GitHub API
# Focuses on: bllvm-consensus, bllvm-protocol, bllvm-node, bllvm-sdk

set -euo pipefail

# Configuration
ORG="${GITHUB_ORG:-BTCDecoded}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
REPOS=("commons" "bllvm-consensus" "bllvm-protocol" "bllvm-node" "bllvm-sdk")
OUTPUT_DIR="${OUTPUT_DIR:-./workflow-logs}"
MAX_RUNS="${MAX_RUNS:-5}"  # Number of recent runs to download per workflow

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to list workflow runs for a repository
list_workflow_runs() {
    local repo="$1"
    local workflow_file="${2:-}"  # Optional: specific workflow file
    
    local url="https://api.github.com/repos/${ORG}/${repo}/actions/runs"
    
    if [ -n "$workflow_file" ]; then
        # Get workflow ID first
        local workflows_url="repos/${ORG}/${repo}/actions/workflows"
        local workflows_json=$(api_request "$workflows_url")
        local workflow_id=$(echo "$workflows_json" | jq -r ".workflows[] | select(.path == \".github/workflows/${workflow_file}\") | .id")
        
        if [ -z "$workflow_id" ] || [ "$workflow_id" = "null" ]; then
            print_warning "Workflow file ${workflow_file} not found in ${repo}"
            return 1
        fi
        
        url="repos/${ORG}/${repo}/actions/workflows/${workflow_id}/runs"
    fi
    
    # Add per_page parameter to limit results
    url="${url}?per_page=${MAX_RUNS}&status=completed"
    
    api_request "$url"
}

# Function to download logs for a specific run
download_run_logs() {
    local repo="$1"
    local run_id="$2"
    local output_path="$3"
    
    local url="repos/${ORG}/${repo}/actions/runs/${run_id}/logs"
    
    print_info "Downloading logs for run ${run_id} from ${repo}..."
    
    # The API returns a redirect to a zip file, so we use -L to follow redirects
    local http_code
    if [ -n "$TOKEN" ]; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token ${TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            -L -o "${output_path}" \
            "https://api.github.com/${url}")
    elif [ "$gh_available" = true ]; then
        # gh CLI handles redirects automatically
        if gh api "$url" -X GET --output "$output_path" >/dev/null 2>&1; then
            http_code="200"
        else
            http_code="404"
        fi
    else
        print_error "No credentials available"
        return 1
    fi
    
    if [ "$http_code" = "200" ]; then
        print_success "Downloaded logs to ${output_path}"
        # Check if file is actually a zip (logs endpoint returns zip)
        # Check file size > 0 and file type
        if [ -s "${output_path}" ] && (file "${output_path}" | grep -qiE "zip|archive" || unzip -t "${output_path}" >/dev/null 2>&1); then
            return 0
        else
            print_warning "Downloaded file may not be a valid zip archive"
            # Try to validate with unzip
            if unzip -t "${output_path}" >/dev/null 2>&1; then
                return 0
            fi
            return 1
        fi
    elif [ "$http_code" = "404" ]; then
        print_error "Logs not found for run ${run_id} (may have expired)"
        rm -f "${output_path}"
        return 1
    else
        print_error "Failed to download logs (HTTP ${http_code})"
        rm -f "${output_path}"
        return 1
    fi
}

# Function to process workflow runs for a repository
process_repo_workflows() {
    local repo="$1"
    
    print_info "Processing workflows for ${repo}..."
    
    # Get all workflows for this repo
    local workflows_url="repos/${ORG}/${repo}/actions/workflows"
    local workflows_json=$(api_request "$workflows_url")
    
    if [ -z "$workflows_json" ] || echo "$workflows_json" | jq -e '.message' > /dev/null 2>&1; then
        print_error "Failed to access ${repo} or repository not found"
        return 1
    fi
    
    local workflow_count=$(echo "$workflows_json" | jq '.workflows | length')
    print_info "Found ${workflow_count} workflow(s) in ${repo}"
    
    # Process each workflow
    echo "$workflows_json" | jq -r '.workflows[] | "\(.id)|\(.name)|\(.path)"' | while IFS='|' read -r workflow_id workflow_name workflow_path; do
        # Extract workflow file name from path
        local workflow_file=$(basename "$workflow_path")
        
        print_info "  Workflow: ${workflow_name} (${workflow_file})"
        
        # Get runs for this workflow
        local runs_url="repos/${ORG}/${repo}/actions/workflows/${workflow_id}/runs?per_page=${MAX_RUNS}&status=completed"
        local runs_json=$(api_request "$runs_url")
        
        local run_count=$(echo "$runs_json" | jq '.workflow_runs | length')
        print_info "    Found ${run_count} completed run(s)"
        
        # Download logs for each run
        echo "$runs_json" | jq -r '.workflow_runs[] | "\(.id)|\(.run_number)|\(.conclusion)|\(.created_at)"' | while IFS='|' read -r run_id run_number conclusion created_at; do
            # Create safe filename
            local safe_name=$(echo "$workflow_name" | tr ' ' '_' | tr '/' '_')
            local output_file="${OUTPUT_DIR}/${repo}/${safe_name}/run_${run_number}_${run_id}.zip"
            mkdir -p "$(dirname "$output_file")"
            
            # Only download if file doesn't exist
            if [ -f "$output_file" ]; then
                print_info "    Skipping run #${run_number} (already downloaded)"
                continue
            fi
            
            if download_run_logs "$repo" "$run_id" "$output_file"; then
                # Extract zip to view contents
                local extract_dir="${output_file%.zip}"
                mkdir -p "$extract_dir"
                if unzip -q -o "$output_file" -d "$extract_dir" 2>/dev/null; then
                    print_success "    Extracted logs to ${extract_dir}"
                else
                    print_warning "    Failed to extract ${output_file}"
                fi
            elif [ -f "$output_file" ] && [ -s "$output_file" ]; then
                # File exists but validation failed - try to extract anyway
                print_info "    Attempting to extract despite validation warning..."
                local extract_dir="${output_file%.zip}"
                mkdir -p "$extract_dir"
                if unzip -q -o "$output_file" -d "$extract_dir" 2>/dev/null; then
                    print_success "    Extracted logs to ${extract_dir}"
                else
                    print_warning "    Could not extract ${output_file}"
                fi
            fi
        done
    done
}

# Function to filter workflows by name pattern
filter_relevant_workflows() {
    local repo="$1"
    
    case "$repo" in
        "bllvm-consensus")
            # Look for verification workflows
            process_repo_workflows "$repo"
            ;;
        "bllvm-protocol"|"bllvm-node"|"bllvm-sdk")
            # Look for build workflows
            process_repo_workflows "$repo"
            ;;
        "commons")
            # Look for orchestrator and reusable workflows
            process_repo_workflows "$repo"
            ;;
        *)
            process_repo_workflows "$repo"
            ;;
    esac
}

# Main execution
main() {
    print_info "GitHub Workflow Logs Downloader"
    print_info "Organization: ${ORG}"
    print_info "Output directory: ${OUTPUT_DIR}"
    print_info "Max runs per workflow: ${MAX_RUNS}"
    echo ""
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
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
    
    # Process each repository
    for repo in "${REPOS[@]}"; do
        echo ""
        print_info "=== Processing ${repo} ==="
        filter_relevant_workflows "$repo"
    done
    
    echo ""
    print_success "Download complete! Logs saved to ${OUTPUT_DIR}"
    
    # Print summary
    echo ""
    print_info "Summary:"
    for repo in "${REPOS[@]}"; do
        local repo_dir="${OUTPUT_DIR}/${repo}"
        if [ -d "$repo_dir" ]; then
            local file_count=$(find "$repo_dir" -name "*.zip" | wc -l)
            print_info "  ${repo}: ${file_count} log file(s)"
        fi
    done
}

# Run main function
main "$@"
