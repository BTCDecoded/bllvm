# BTCDecoded Commons Scripts

This directory contains utility scripts for managing BTCDecoded workflows, runners, and CI/CD operations.

## Scripts

### Workflow Monitoring

#### `monitor-workflows.sh`
Monitor workflow execution across BTCDecoded repositories.

```bash
# Monitor commons repository
./monitor-workflows.sh commons

# Monitor specific workflow
./monitor-workflows.sh consensus-proof verify_consensus.yml
```

**Environment Variables:**
- `GITHUB_TOKEN` or `GH_TOKEN` - GitHub authentication token
- `GITHUB_ORG` - GitHub organization (default: BTCDecoded)

#### `check-ci-status.sh`
Quick CI status check for a repository.

```bash
# Check commons CI status
./check-ci-status.sh commons

# Check specific workflow
./check-ci-status.sh consensus-proof ci.yml
```

#### `ci-healer.sh`
Auto-healing CI/CD pipeline monitor that automatically fixes common issues.

```bash
# Start auto-healer (monitor and fix)
./ci-healer.sh

# Monitor only (no auto-fix)
./ci-healer.sh --no-auto-fix

# Custom interval
./ci-healer.sh -i 60

# Monitor specific repository
./ci-healer.sh -r consensus-proof -w ci.yml
```

**Features:**
- Automatically detects and retries failed workflows
- Identifies stuck workflows (>30 minutes)
- Monitors workflow conflicts
- Configurable check intervals
- Logs all actions

### Runner Management

#### `runner-status.sh`
Comprehensive runner status report showing runners, workflows, and system resources.

```bash
# Check organization runners
./runner-status.sh

# Check specific organization
./runner-status.sh BTCDecoded
```

**Shows:**
- Runner status (online/offline, busy/idle)
- Runner labels
- Latest workflow runs across repositories
- Active/queued workflow counts
- System resources (memory, disk)

#### `start-runner.sh`
Start a GitHub Actions self-hosted runner.

```bash
# Start runner in current directory
./start-runner.sh

# Start runner in specific directory
./start-runner.sh /opt/actions-runner
```

**Checks:**
- Verifies runner is properly configured
- Detects if runner is already running
- Can start as service or directly

### Workflow Management

#### `cancel-old-jobs.sh`
Cancel old queued workflow runs, keeping only the most recent.

```bash
# Cancel old jobs in commons
./cancel-old-jobs.sh commons

# Cancel old jobs for specific workflow
./cancel-old-jobs.sh consensus-proof verify_consensus
```

## Requirements

All scripts require:
- `bash` 4.0+
- `curl` for GitHub API calls
- `jq` for JSON parsing
- `GITHUB_TOKEN` or `GH_TOKEN` environment variable

Alternatively, use `gh` CLI authenticated:
```bash
gh auth login
```

## Bootstrap Script

The bootstrap script (`../tools/bootstrap_runner.sh`) sets up a self-hosted runner with required toolchains.

```bash
# Install all tools
sudo ../tools/bootstrap_runner.sh --all

# Install specific tools
sudo ../tools/bootstrap_runner.sh --rust --docker --kani

# Setup cache directory
sudo ../tools/bootstrap_runner.sh --cache-dir /opt/cache
```

## Local Caching

Scripts support local caching for faster builds. The bootstrap script sets up cache directories at `/tmp/runner-cache` by default.

**Cache Structure:**
```
/tmp/runner-cache/
├── deps/          # Dependency caches
├── builds/        # Build artifacts
├── cargo-registry/ # Cargo registry cache
└── cargo-git/     # Cargo git cache
```

## Examples

### Monitor All Workflows
```bash
# Monitor commons release orchestrator
./monitor-workflows.sh commons release_orchestrator.yml

# Monitor consensus-proof verification
./monitor-workflows.sh consensus-proof verify_consensus.yml
```

### Auto-Heal CI Issues
```bash
# Start auto-healer for commons
./ci-healer.sh -r commons -w release_orchestrator.yml

# Monitor only (no fixes)
./ci-healer.sh --no-auto-fix -r consensus-proof
```

### Check Runner Status
```bash
# Full status report
./runner-status.sh

# Check specific org
./runner-status.sh BTCDecoded
```

### Clean Up Queued Jobs
```bash
# Cancel old queued jobs
./cancel-old-jobs.sh commons release_orchestrator

# Cancel all old jobs in consensus-proof
./cancel-old-jobs.sh consensus-proof
```

## Integration with Workflows

These scripts complement the reusable workflows in `../.github/workflows/`:

- **Reusable Workflows**: Handle actual build/verification logic
- **Monitoring Scripts**: Track workflow execution and health
- **Runner Scripts**: Manage runner lifecycle and status

## Troubleshooting

### Token Issues
```bash
# Check token validity
gh auth status

# Set token
export GITHUB_TOKEN="your-token-here"
```

### Runner Not Found
```bash
# Check runner status
./runner-status.sh

# Verify runner is online
gh api orgs/BTCDecoded/actions/runners
```

### Workflow Failures
```bash
# Use auto-healer to diagnose and fix
./ci-healer.sh -r <repo> -w <workflow>

# Check specific workflow status
./check-ci-status.sh <repo> <workflow-file>
```

## See Also

- `../tools/bootstrap_runner.sh` - Runner bootstrap script
- `../ops/SELF_HOSTED_RUNNER.md` - Runner setup documentation
- `../ops/RUNNER_FLEET.md` - Runner fleet management
- `../WORKFLOW_METHODOLOGY.md` - Workflow methodology

