# GitHub Workflow Logs Downloader

This script downloads workflow logs from GitHub Actions using the **proper GitHub REST API endpoints**.

## How It Works

The script uses the official GitHub REST API v3 to download workflow logs:

1. **List Workflows**: `GET /repos/{owner}/{repo}/actions/workflows`
   - Gets all workflows defined in a repository
   
2. **List Workflow Runs**: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs`
   - Gets recent workflow runs for each workflow
   - Filters to completed runs only
   
3. **Download Logs**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`
   - Downloads logs as a ZIP archive
   - The API returns a redirect (302) to the actual zip file
   - Uses `curl -L` to follow the redirect automatically

## Usage

```bash
# Basic usage (uses default token from script)
./scripts/download_workflow_logs.sh

# Custom output directory
OUTPUT_DIR=./my-logs ./scripts/download_workflow_logs.sh

# Download more runs per workflow
MAX_RUNS=10 ./scripts/download_workflow_logs.sh

# Use environment variable for token (more secure)
GITHUB_TOKEN=ghp_... ./scripts/download_workflow_logs.sh
```

## What It Downloads

The script focuses on these repositories:
- `commons` - Build orchestrator and reusable workflows
- `consensus-proof` - Verification workflows
- `protocol-engine` - Build workflows
- `reference-node` - Build workflows
- `developer-sdk` - Build workflows

For each repository, it:
1. Lists all workflows
2. Gets the most recent completed runs (default: 5 per workflow)
3. Downloads logs as ZIP files
4. Extracts the ZIP files for easy viewing

## Output Structure

```
workflow-logs/
├── commons/
│   ├── Release_Orchestrator/
│   │   ├── run_1_12345678.zip
│   │   └── run_1_12345678/  (extracted)
│   └── Build_Library_Binary/
│       └── ...
├── consensus-proof/
│   └── Verify_Consensus/
│       └── ...
├── protocol-engine/
├── reference-node/
└── developer-sdk/
```

## API Endpoints Used

### Proper GitHub API Method

1. **List workflows**: 
   ```
   GET https://api.github.com/repos/{owner}/{repo}/actions/workflows
   ```

2. **List workflow runs**:
   ```
   GET https://api.github.com/repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs?per_page={n}&status=completed
   ```

3. **Download logs** (returns redirect to zip):
   ```
   GET https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/logs
   ```
   - Response: 302 redirect to `https://pipelines.actions.githubusercontent.com/...`
   - Must use `curl -L` to follow redirect

## Requirements

- `curl` - For API requests
- `jq` - For JSON parsing
- `unzip` - For extracting downloaded logs (optional)

## Security Notes

- The GitHub token is stored in the script by default, but you can override it with `GITHUB_TOKEN` environment variable
- Token needs `repo` and `actions:read` permissions
- Logs may expire after 90 days (GitHub retention policy)

## Why This Method is Correct

1. **Official API**: Uses GitHub's documented REST API endpoints
2. **Proper Authentication**: Uses token-based authentication
3. **Handles Redirects**: The logs endpoint returns a redirect, which `curl -L` properly follows
4. **Respects Rate Limits**: Uses standard API requests (rate limits apply)
5. **Complete Data**: Downloads full logs including all jobs and steps

## Alternative Methods (Not Recommended)

- ❌ Screen scraping the GitHub UI
- ❌ Using undocumented endpoints
- ❌ Manual download from web UI (not scalable)

## Troubleshooting

### "Authentication failed"
- Check that your token has `repo` and `actions:read` scopes
- Verify the token hasn't expired

### "Logs not found (404)"
- Logs may have expired (GitHub retains logs for 90 days)
- The workflow run may still be in progress

### "jq: command not found"
- Install jq: `sudo apt-get install jq` (Debian/Ubuntu) or `brew install jq` (macOS)

### Rate Limit Errors
- GitHub API has rate limits (5000 requests/hour for authenticated users)
- The script caches results and skips already-downloaded files to minimize requests
