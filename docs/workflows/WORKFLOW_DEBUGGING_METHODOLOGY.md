# GitHub Actions Workflow Debugging Methodology

## Overview

This document describes the methodology for effectively debugging, monitoring, and iterating on GitHub Actions workflows using minimal tooling and direct API access. This approach emphasizes rapid iteration, real-time monitoring, and adaptive problem-solving without heavy scripting.

## Core Principles

1. **Direct API Access**: Use GitHub REST API with `curl` for all workflow operations
2. **Minimal Scripting**: Prefer inline commands over complex scripts
3. **Iterative Debugging**: Monitor → Identify → Fix → Re-run → Verify
4. **Real-time Monitoring**: Use blocking commands with appropriate sleep intervals
5. **Adaptive Problem Solving**: Let errors guide the next steps

## Prerequisites

### API Token Setup

You need a GitHub Personal Access Token (PAT) with the following permissions:
- `repo` (full control of private repositories)
- `workflow` (update GitHub Action workflows)
- `read:org` (if working with organization repos)

**Important**: Store the token securely. Never commit it to the repository. Use it as an environment variable or pass it directly in commands.

```bash
# Example: Set as environment variable (recommended)
export GITHUB_TOKEN="ghp_your_token_here"

# Or use directly in commands (less secure, but acceptable for debugging)
GITHUB_TOKEN="ghp_your_token_here"
```

### Required Tools

- `curl` - For GitHub API access
- `jq` - For JSON parsing and filtering
- `bash` - For command execution
- `git` - For committing fixes

## Workflow Operations

### 1. Triggering Workflows

#### Manual Workflow Dispatch

```bash
# Trigger a workflow_dispatch event
curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/workflows/WORKFLOW_FILE.yml/dispatches" \
  -d '{
    "ref": "main",
    "inputs": {
      "version_tag": "v0.2.0-prerelease",
      "platform": "linux"
    }
  }'
```

**Key Parameters:**
- `ref`: Branch or tag to run from (usually `"main"`)
- `inputs`: Workflow input parameters (varies by workflow)
- `WORKFLOW_FILE.yml`: The workflow file name (e.g., `prerelease.yml`)

#### Finding Workflow IDs

```bash
# Get workflow ID by filename
curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/workflows/WORKFLOW_FILE.yml" | \
  jq -r '.id'
```

### 2. Monitoring Workflow Status

#### Get Latest Workflow Run

```bash
# Get the most recent run of a specific workflow
curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/workflows/WORKFLOW_ID/runs?per_page=1" | \
  jq -r '.workflow_runs[0] | "Run ID: \(.id) | Status: \(.status) | Conclusion: \(.conclusion // "pending") | URL: \(.html_url)"'
```

#### Get Run Details

```bash
# Get detailed information about a specific run
RUN_ID=123456789
curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
  jq '.'
```

#### Monitor with Blocking Sleep

```bash
# Monitor workflow with blocking sleep (wait for completion)
WORKFLOW_ID=123456789
while true; do
  STATUS=$(curl -s \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
    jq -r '.status')
  
  echo "Status: ${STATUS}"
  
  if [ "$STATUS" = "completed" ]; then
    CONCLUSION=$(curl -s \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
      jq -r '.conclusion')
    echo "Conclusion: ${CONCLUSION}"
    break
  fi
  
  sleep 10  # Check every 10 seconds
done
```

### 3. Getting Workflow Logs

#### Get Job Information

```bash
# Get all jobs for a workflow run
RUN_ID=123456789
curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}/jobs" | \
  jq -r '.jobs[] | "\(.name): \(.conclusion // "pending")"'
```

#### Get Job Logs

**Note**: GitHub API doesn't provide direct log download via REST API. Logs are available through:
1. The web UI (HTML URL from run details)
2. GitHub CLI (`gh run view --log`)
3. Downloading as artifacts (if workflow uploads them)

For debugging, use the web UI URL from the run details:

```bash
# Get the HTML URL for viewing logs in browser
RUN_ID=123456789
LOG_URL=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
  jq -r '.html_url')
  
echo "View logs at: ${LOG_URL}"
```

#### Alternative: Use GitHub CLI (if available)

```bash
# Install GitHub CLI if not available
# Then authenticate: gh auth login

# View logs directly
gh run view ${RUN_ID} --log

# Or view specific job
gh run view ${RUN_ID} --job ${JOB_ID} --log
```

### 4. Iterative Debugging Workflow

#### Complete Monitoring and Debugging Cycle

```bash
# Step 1: Trigger workflow
curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/workflows/prerelease.yml/dispatches" \
  -d '{"ref":"main","inputs":{"version_tag":"v0.2.0-prerelease","platform":"linux"}}'

# Step 2: Wait a moment for workflow to start
sleep 5

# Step 3: Get the run ID
RUN_ID=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/workflows/prerelease.yml/runs?per_page=1" | \
  jq -r '.workflow_runs[0].id')

echo "Monitoring run: ${RUN_ID}"

# Step 4: Monitor until completion
while true; do
  STATUS=$(curl -s \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
    jq -r '.status')
  
  if [ "$STATUS" = "completed" ]; then
    CONCLUSION=$(curl -s \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
      jq -r '.conclusion')
    
    HTML_URL=$(curl -s \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}" | \
      jq -r '.html_url')
    
    echo "Workflow completed with conclusion: ${CONCLUSION}"
    echo "View logs: ${HTML_URL}"
    break
  fi
  
  echo "Status: ${STATUS}, waiting..."
  sleep 15  # Adjust based on typical workflow duration
done
```

## Debugging Methodology

### 1. Error Identification

When a workflow fails:

1. **Get the run details** to see which job failed
2. **Check the conclusion** (failure, cancelled, etc.)
3. **Review the HTML URL** to see detailed logs
4. **Identify the specific error** from the logs

### 2. Fix Application

Based on the error:

1. **Read the relevant files** (workflow YAML, scripts, source code)
2. **Identify the root cause** (syntax error, missing dependency, logic error)
3. **Apply the fix** using appropriate tools (search_replace, write, etc.)
4. **Commit the fix** with a descriptive message

### 3. Re-run and Verify

1. **Trigger the workflow again** with the same parameters
2. **Monitor the new run** to verify the fix
3. **Iterate** if new errors appear

### Example: Complete Debugging Session

```bash
# Set token (do this once per session)
export GITHUB_TOKEN="ghp_your_token_here"
REPO="BTCDecoded/bllvm"

# Trigger workflow
echo "Triggering workflow..."
curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/workflows/prerelease.yml/dispatches" \
  -d '{"ref":"main","inputs":{"version_tag":"v0.2.0-prerelease","platform":"linux"}}'

# Wait for workflow to start
sleep 5

# Get run ID
RUN_ID=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/workflows/prerelease.yml/runs?per_page=1" | \
  jq -r '.workflow_runs[0].id')

echo "Run ID: ${RUN_ID}"

# Monitor with appropriate sleep interval
# For fast workflows (10-30 seconds), use shorter intervals
# For slow workflows (minutes), use longer intervals
sleep 30

# Check status
STATUS=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}" | \
  jq -r '.status')

CONCLUSION=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}" | \
  jq -r '.conclusion // "pending"')

HTML_URL=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}" | \
  jq -r '.html_url')

echo "Status: ${STATUS}"
echo "Conclusion: ${CONCLUSION}"
echo "View logs: ${HTML_URL}"

# If failed, get job details
if [ "$CONCLUSION" = "failure" ]; then
  echo "Getting failed job details..."
  curl -s \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/jobs" | \
    jq -r '.jobs[] | select(.conclusion == "failure") | "\(.name): \(.html_url)"'
fi
```

## Best Practices

### 1. Sleep Intervals

- **Fast workflows** (< 1 minute): Sleep 5-10 seconds
- **Medium workflows** (1-5 minutes): Sleep 15-30 seconds
- **Slow workflows** (> 5 minutes): Sleep 30-60 seconds
- **Very slow workflows** (> 15 minutes): Sleep 60+ seconds

**Rule of thumb**: Sleep interval should be ~10% of expected workflow duration, but never less than 5 seconds.

### 2. Error Handling

Always check for errors in API responses:

```bash
# Check if API call succeeded
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/runs/${RUN_ID}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: HTTP ${HTTP_CODE}"
  echo "$BODY" | jq '.'
  exit 1
fi
```

### 3. Rate Limiting

GitHub API has rate limits:
- **Authenticated requests**: 5,000 requests/hour
- **Unauthenticated requests**: 60 requests/hour

If you hit rate limits, add delays between requests or use the `X-RateLimit-Remaining` header to monitor usage.

### 4. Workflow File Validation

Before committing workflow changes, validate the YAML:

```bash
# Check workflow syntax (if yamllint is available)
yamllint .github/workflows/prerelease.yml

# Or use GitHub's validation (commit and let it fail if invalid)
# Better: Test locally with act (GitHub Actions local runner)
```

### 5. Commit Strategy

- **One fix per commit**: Makes it easier to identify what fixed what
- **Descriptive messages**: Include the error being fixed
- **Test before committing**: If possible, validate locally first

Example commit messages:
- `fix: correct feature flags for bllvm-sdk in build.sh`
- `fix: update deterministic build verification to use correct feature flags`
- `refactor: separate bllvm binary and governance tools into distinct archives`

## Common Patterns

### Pattern 1: Trigger → Monitor → Fix → Re-trigger

```bash
# 1. Trigger
curl -X POST ... "dispatches" -d '{...}'

# 2. Monitor (with sleep)
sleep 30
curl ... "runs?per_page=1" | jq '...'

# 3. If failed, fix the issue in code
# (Use search_replace, write, etc.)

# 4. Commit and push
git add . && git commit -m "fix: ..." && git push

# 5. Re-trigger
curl -X POST ... "dispatches" -d '{...}'
```

### Pattern 2: Continuous Monitoring

```bash
# Monitor until completion
while true; do
  STATUS=$(curl ... | jq -r '.status')
  if [ "$STATUS" = "completed" ]; then
    break
  fi
  sleep 15
done
```

### Pattern 3: Error Extraction

```bash
# Get failed job and extract error details
FAILED_JOBS=$(curl ... "/jobs" | jq -r '.jobs[] | select(.conclusion == "failure")')
# Then view logs via HTML URL or extract from job details
```

## Troubleshooting

### Workflow Not Triggering

- Check workflow file syntax (YAML errors)
- Verify `workflow_dispatch` is enabled
- Check input parameter names match exactly
- Ensure branch exists and workflow file is on that branch

### Can't Get Logs

- Use HTML URL from run details (most reliable)
- Check if logs are still being generated (status = "in_progress")
- Verify API token has `actions:read` permission

### Rate Limiting

- Add delays between API calls
- Use longer sleep intervals
- Check `X-RateLimit-Remaining` header
- Consider using GitHub CLI (`gh`) which handles rate limiting better

## Example: Complete Workflow Debugging Session

```bash
#!/bin/bash
# Example: Debugging a prerelease workflow

set -e

GITHUB_TOKEN="ghp_your_token_here"  # Set your token
REPO="BTCDecoded/bllvm"
WORKFLOW="prerelease.yml"

echo "=== Step 1: Trigger Workflow ==="
curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/dispatches" \
  -d '{
    "ref": "main",
    "inputs": {
      "version_tag": "v0.2.0-prerelease",
      "platform": "linux"
    }
  }'

echo "Workflow triggered, waiting for it to start..."
sleep 5

echo "=== Step 2: Get Run ID ==="
RUN_INFO=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/runs?per_page=1")

RUN_ID=$(echo "$RUN_INFO" | jq -r '.workflow_runs[0].id')
HTML_URL=$(echo "$RUN_INFO" | jq -r '.workflow_runs[0].html_url')

echo "Run ID: ${RUN_ID}"
echo "View at: ${HTML_URL}"

echo "=== Step 3: Monitor Progress ==="
# For a typical build workflow, check every 30 seconds
for i in {1..20}; do  # Check up to 20 times (10 minutes)
  RUN_STATUS=$(curl -s \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}")
  
  STATUS=$(echo "$RUN_STATUS" | jq -r '.status')
  CONCLUSION=$(echo "$RUN_STATUS" | jq -r '.conclusion // "pending"')
  
  echo "[$(date +%H:%M:%S)] Status: ${STATUS}, Conclusion: ${CONCLUSION}"
  
  if [ "$STATUS" = "completed" ]; then
    echo ""
    echo "=== Workflow Completed ==="
    echo "Conclusion: ${CONCLUSION}"
    echo "View logs: ${HTML_URL}"
    
    if [ "$CONCLUSION" = "failure" ]; then
      echo ""
      echo "=== Failed Jobs ==="
      curl -s \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/jobs" | \
        jq -r '.jobs[] | select(.conclusion == "failure") | "\(.name): \(.html_url)"'
    fi
    
    break
  fi
  
  sleep 30
done
```

## Key Takeaways

1. **Use direct API calls** - No need for complex scripts
2. **Blocking sleep is fine** - For monitoring, simple `sleep` commands work well
3. **Let errors guide you** - Each error tells you what to fix next
4. **Iterate quickly** - Fix → Commit → Push → Re-run
5. **Monitor appropriately** - Adjust sleep intervals based on workflow duration
6. **Use HTML URLs** - Most reliable way to view detailed logs
7. **One fix per commit** - Makes debugging history clear

## Security Notes

- **Never commit API tokens** to the repository
- **Use environment variables** or secure storage for tokens
- **Rotate tokens regularly** if exposed
- **Use minimal permissions** - Only grant what's needed
- **Review token scope** - `repo` and `workflow` are sufficient for most tasks

## Additional Resources

- [GitHub Actions REST API Documentation](https://docs.github.com/en/rest/actions)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Workflow Syntax Reference](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

