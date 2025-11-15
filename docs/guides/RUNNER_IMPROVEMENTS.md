# Runner and Script Improvements

**Date:** 2025-01-XX  
**Status:** Implemented

## Overview

This document summarizes improvements made to BTCDecoded runner infrastructure and scripts, incorporating best practices from MyBitcoinFuture's operational experience.

## New Scripts Added

### Workflow Monitoring

1. **`scripts/monitor-workflows.sh`**
   - Monitors workflow execution across BTCDecoded repositories
   - Shows job status with color-coded output
   - Supports monitoring specific workflows
   - Works with GitHub API or `gh` CLI

2. **`scripts/check-ci-status.sh`**
   - Quick CI status check for any repository
   - Lightweight script for fast status queries
   - No external dependencies beyond curl/jq or gh CLI
   - Perfect for quick checks without full monitoring

3. **`scripts/ci-healer.sh`**
   - Auto-healing CI/CD pipeline monitor
   - Automatically detects and retries failed workflows
   - Identifies stuck workflows (>30 minutes)
   - Configurable monitoring intervals
   - Comprehensive logging
   - Can run in monitor-only mode

### Runner Management

4. **`scripts/runner-status.sh`**
   - Comprehensive runner status report
   - Shows all runners in organization
   - Displays latest workflow runs across repositories
   - Shows active/queued workflow counts
   - Includes system resource information
   - Color-coded output for quick status assessment

5. **`scripts/start-runner.sh`**
   - Start GitHub Actions self-hosted runner
   - Detects if runner is already running
   - Supports service mode or direct execution
   - Provides helpful error messages and setup guidance

6. **`scripts/cancel-old-jobs.sh`**
   - Cancel old queued workflow runs
   - Keeps most recent run
   - Prevents queue buildup
   - Useful for cleanup operations

### Caching

7. **`scripts/setup-cache.sh`**
   - Sets up local cache directory structure
   - Configures Cargo cache directories
   - Creates cleanup script
   - Sets proper permissions

## Enhanced Scripts

### `tools/bootstrap_runner.sh`

**Improvements:**
- ✅ Color-coded output for better readability
- ✅ Better error handling and user feedback
- ✅ Checks for existing installations (avoids re-install)
- ✅ Cache directory setup option (`--cache-dir`)
- ✅ `--all` flag for complete setup
- ✅ Help documentation
- ✅ Summary of installed components
- ✅ Next steps guidance

**New Features:**
- Cache directory creation and configuration
- Better detection of existing tools
- Improved user experience with colored output
- Comprehensive help text

## Features from MyBitcoinFuture

### Adopted Practices

1. **Local Caching System**
   - `/tmp/runner-cache` directory structure
   - Separate caches for deps, builds, cargo registry
   - Cleanup scripts for maintenance
   - Faster builds through local caching

2. **Monitoring Infrastructure**
   - Workflow monitoring scripts
   - CI status checking
   - Auto-healing capabilities
   - Comprehensive status reports

3. **Runner Management**
   - Runner status reporting
   - Runner startup scripts
   - Job cancellation utilities
   - Resource monitoring

4. **User Experience**
   - Color-coded output
   - Clear error messages
   - Helpful guidance
   - Comprehensive documentation

### Adapted for BTCDecoded

- **Rust-specific**: Adapted for Cargo caching instead of npm
- **Organization-focused**: Works with BTCDecoded org structure
- **Workflow-aware**: Understands BTCDecoded workflow patterns
- **Multi-repo**: Supports monitoring across all BTCDecoded repos

## Script Capabilities

### Monitoring
- ✅ Real-time workflow status
- ✅ Job-level monitoring
- ✅ Runner status tracking
- ✅ System resource monitoring
- ✅ Stuck workflow detection

### Automation
- ✅ Auto-retry failed workflows
- ✅ Automatic cleanup of old jobs
- ✅ Cache management
- ✅ Runner lifecycle management

### Reporting
- ✅ Comprehensive status reports
- ✅ Color-coded output
- ✅ Logging capabilities
- ✅ Resource usage tracking

## Usage Examples

### Monitor Workflows
```bash
# Monitor commons release orchestrator
./scripts/monitor-workflows.sh commons release_orchestrator.yml

# Monitor all bllvm-consensus workflows
./scripts/monitor-workflows.sh bllvm-consensus
```

### Auto-Heal CI
```bash
# Start auto-healer
./scripts/ci-healer.sh -r commons -w release_orchestrator.yml

# Monitor only (no fixes)
./scripts/ci-healer.sh --no-auto-fix
```

### Check Status
```bash
# Full runner status
./scripts/runner-status.sh

# Quick CI check
./scripts/check-ci-status.sh bllvm-consensus
```

### Setup Runner
```bash
# Bootstrap runner with all tools
sudo ../tools/bootstrap_runner.sh --all

# Setup cache
sudo ./scripts/setup-cache.sh
```

## Integration

### With Workflows
- Scripts complement reusable workflows in `.github/workflows/`
- Monitoring scripts track workflow execution
- Auto-healer fixes common workflow issues
- Status scripts provide visibility

### With Runners
- Bootstrap script sets up runners
- Start script manages runner lifecycle
- Status script monitors runner health
- Cache setup optimizes runner performance

## Documentation

All scripts include:
- ✅ Comprehensive help text (`--help`)
- ✅ Usage examples
- ✅ Environment variable documentation
- ✅ Error messages with guidance
- ✅ README in scripts directory

## Next Steps

1. **Test Scripts**: Verify all scripts work with actual runners
2. **Documentation**: Add to main README and workflow docs
3. **Integration**: Integrate monitoring into CI/CD workflows
4. **Automation**: Set up periodic status reports
5. **Monitoring**: Configure alerts for critical failures

## Comparison with MyBitcoinFuture

| Feature | MyBitcoinFuture | BTCDecoded | Status |
|---------|----------------|------------|--------|
| Workflow Monitoring | ✅ | ✅ | Implemented |
| CI Auto-Healing | ✅ | ✅ | Implemented |
| Runner Status | ✅ | ✅ | Implemented |
| Local Caching | ✅ | ✅ | Implemented |
| Job Cancellation | ✅ | ✅ | Implemented |
| Runner Bootstrap | ✅ | ✅ | Enhanced |
| Cache Setup | ✅ | ✅ | Implemented |
| Documentation | ✅ | ✅ | Comprehensive |

## Benefits

1. **Operational Excellence**
   - Better visibility into CI/CD health
   - Automated issue detection and resolution
   - Proactive monitoring

2. **Performance**
   - Local caching reduces build times
   - Efficient cache management
   - Optimized runner utilization

3. **Reliability**
   - Auto-healing prevents stuck workflows
   - Job cancellation prevents queue buildup
   - Status monitoring enables quick response

4. **Developer Experience**
   - Easy-to-use scripts
   - Clear documentation
   - Helpful error messages
   - Color-coded output

## See Also

- `scripts/README.md` - Complete script documentation
- `ops/SELF_HOSTED_RUNNER.md` - Runner setup guide
- `ops/RUNNER_FLEET.md` - Runner fleet management
- `WORKFLOW_METHODOLOGY.md` - Workflow methodology

