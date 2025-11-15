# Commons Scripts

This directory contains build, CI, and release scripts for the Bitcoin Commons build orchestration system.

## Script Categories

### Build Scripts
- `build-release-chain.sh` - Build release chain for all components
- `setup-build-env.sh` - Set up build environment
- `setup-cache.sh` - Set up build cache

### CI/CD Scripts
- `check-workflow-status.sh` - Check GitHub workflow status
- `check-ci-status.sh` - Check CI status
- `monitor-workflows.sh` - Monitor GitHub workflows
- `cancel-old-jobs.sh` - Cancel old CI jobs
- `ci-healer.sh` - CI health monitoring
- `download-workflow-logs.sh` - Download workflow logs
- `runner-status.sh` - Check runner status
- `start-runner.sh` - Start CI runner

### Verification Scripts
- `verify_formal_coverage.sh` - Verify formal verification coverage
- `verify-versions.sh` - Verify version consistency

### Release Scripts
- `create-release.sh` - Create release
- `collect-artifacts.sh` - Collect release artifacts

## Usage

See [commons/README.md](../README.md) for build system documentation and usage instructions.

## Related Scripts

- `../tools/` - Build tools (bootstrap_runner.sh, run_suite.sh, etc.)
- `../../scripts/` - Benchmarking and analysis scripts
- Component-specific scripts in component directories
