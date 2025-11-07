# Bitcoin Commons - Build and Release System

This repository contains the unified build orchestration and release automation infrastructure for the Bitcoin Commons ecosystem.

> **For verified system status**: See [SYSTEM_STATUS.md](https://github.com/BTCDecoded/.github/blob/main/SYSTEM_STATUS.md) in the BTCDecoded organization repository.

## Overview

The Bitcoin Commons project consists of multiple independent git repositories with complex dependencies:

- **consensus-proof** (foundation library)
- **protocol-engine** (depends on consensus-proof)
- **reference-node** (depends on protocol-engine + consensus-proof)
- **developer-sdk** (standalone, CLI tools)
- **governance-app** (depends on developer-sdk)

This repository provides:

1. **Unified Build Script** (`build.sh`) - Builds all repos in dependency order
2. **Version Coordination** (`versions.toml`) - Tracks compatible versions across repos
3. **Reusable Workflows** - GitHub Actions workflows that other repos can call
4. **Release Automation** - Creates unified releases with all binaries
5. **Helper Scripts** - Utilities for artifact collection and verification

## Quick Start

### Building All Repositories Locally

**Simplest way:**
```bash
# Clone commons repository
git clone https://github.com/BTCDecoded/commons.git
cd commons

# Ensure all Bitcoin Commons repos are cloned in parent directory
# Expected structure:
# BTCDecoded/  # GitHub organization directory
#   ├── commons/
#   ├── consensus-proof/
#   ├── protocol-engine/
#   ├── reference-node/
#   ├── developer-sdk/
#   └── governance-app/

# Build everything (easiest)
./build-local.sh

# Or use full build script
./build.sh --mode dev
```

**For release builds:**
```bash
# Complete release chain
./scripts/build-release-chain.sh
```

See [Quick Start Guide](docs/guides/QUICK_START.md) for more details.

### Using Workflows from Other Repositories

Other repos can call reusable workflows from `commons`:

```yaml
# In reference-node/.github/workflows/build.yml
jobs:
  build:
    uses: BTCDecoded/commons/.github/workflows/build-single.yml@main
    with:
      repo-name: reference-node
      required-deps: consensus-proof,protocol-engine
```

## Structure

```
commons/
├── README.md                    # This file
├── build.sh                     # Main unified build script
├── versions.toml                # Version coordination manifest
├── docker-compose.build.yml     # Docker build orchestration
├── .github/
│   └── workflows/
│       ├── build-all.yml        # Reusable: Build all repos
│       ├── build-single.yml     # Reusable: Build single repo
│       ├── release.yml          # Reusable: Create unified release
│       └── verify-versions.yml  # Reusable: Validate versions
├── scripts/
│   ├── setup-build-env.sh       # Setup build environment
│   ├── collect-artifacts.sh     # Package binaries
│   ├── create-release.sh        # Release creation
│   ├── build-release-chain.sh   # Complete release chain
│   └── verify-versions.sh       # Version validation
├── docs/
│   ├── build/                   # Build system documentation
│   ├── workflows/               # Workflow documentation
│   ├── testing/                 # Testing documentation
│   └── guides/                  # Quick reference guides
└── ops/
    ├── SELF_HOSTED_RUNNER.md    # Runner setup
    └── RUNNER_FLEET.md          # Runner fleet management
```

## Version Coordination

The `versions.toml` file tracks compatible versions across all repositories. This ensures that releases are built with compatible dependency versions.

See `versions.toml` for current version mappings.

## Documentation

Comprehensive documentation is organized in the `docs/` directory:

- **[Build System](docs/build/)** - Build system documentation and guides
- **[Workflows](docs/workflows/)** - Workflow methodology and enhancements
- **[Testing](docs/testing/)** - Testing and validation documentation
- **[Guides](docs/guides/)** - Quick reference guides

See [docs/README.md](docs/README.md) for complete documentation index.

## License

MIT License - see LICENSE file for details.

