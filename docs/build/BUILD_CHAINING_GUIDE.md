# Build Script Chaining Guide

**Date:** 2025-01-XX  
**Status:** Complete Guide

## Overview

This guide explains how to chain build scripts across all BTCDecoded repositories to create a final release. There are multiple approaches depending on your use case.

## Build Architecture

### Dependency Graph

```
bllvm-consensus (L2) ──┐
                       ├──→ bllvm-protocol (L3) ──→ bllvm-node (L4)
bllvm-sdk ─────────┘
                       └──→ governance-app
```

### Build Order

1. **bllvm-consensus** (parallel with bllvm-sdk)
2. **bllvm-sdk** (parallel with bllvm-consensus)
3. **bllvm-protocol** (depends on bllvm-consensus)
4. **bllvm-node** (depends on bllvm-protocol + bllvm-consensus)
5. **governance-app** (depends on bllvm-sdk)

## Approach 1: Using GitHub Actions Workflows (Recommended)

### Automated Release Orchestration

The `release_orchestrator.yml` workflow automatically chains builds across all repos:

```yaml
# Trigger from GitHub Actions UI or CLI
gh workflow run release_orchestrator.yml
```

**What it does:**
1. Reads `versions.toml` to get version tags for each repo
2. Verifies bllvm-consensus (with Kani if enabled)
3. Builds bllvm-protocol (depends on bllvm-consensus)
4. Builds bllvm-node (depends on bllvm-protocol)
5. Builds bllvm-sdk
6. Builds governance-app Docker image (depends on bllvm-sdk)
7. Signals deployment

**Benefits:**
- ✅ Fully automated
- ✅ Uses cached workflows for speed
- ✅ Handles dependencies automatically
- ✅ Runs on self-hosted runners
- ✅ Generates artifacts automatically

### Manual Workflow Trigger

```bash
# From commons repository
gh workflow run release_orchestrator.yml
```

## Approach 2: Local Build Script Chain

### Using `build.sh` (Simple Local Build)

For local development or testing:

```bash
# From commons directory
cd /path/to/BTCDecoded/commons

# Ensure all repos are cloned in parent directory
# BTCDecoded/
#   ├── commons/
#   ├── bllvm-consensus/
#   ├── bllvm-protocol/
#   ├── bllvm-node/
#   ├── bllvm-sdk/
#   └── governance-app/

# Build all repos in dependency order
./build.sh --mode dev    # Uses local path dependencies
./build.sh --mode release # Uses git dependencies (if configured)
```

**What it does:**
1. Checks Rust toolchain (1.70+)
2. Verifies all repos exist
3. Topologically sorts repos by dependencies
4. Builds each repo in order
5. Collects binaries to `artifacts/binaries/`

### Using `build_release_set.sh` (Release Build)

For building a specific release set from `versions.toml`:

```bash
# From commons directory
cd /path/to/BTCDecoded/commons

# Ensure all repos are cloned in BASE directory
# BASE=/path/to/checkouts
# BASE/
#   ├── bllvm-consensus/
#   ├── bllvm-protocol/
#   ├── bllvm-node/
#   ├── bllvm-sdk/
#   └── governance-app/

# Build release set
./tools/build_release_set.sh \
  --base /path/to/checkouts \
  --gov-source \
  --gov-docker \
  --manifest /path/to/output

# Options:
#   --base DIR       : Directory containing all repo checkouts (required)
#   --gov-source    : Build governance-app from source
#   --gov-docker    : Build governance-app Docker image
#   --manifest DIR  : Generate MANIFEST.json in output directory
```

**What it does:**
1. Reads `versions.toml` to get version tags
2. Checks out each repo to the specified tag
3. Builds bllvm-consensus → bllvm-protocol → bllvm-node → bllvm-sdk
4. Optionally builds governance-app (source and/or Docker)
5. Generates SHA256SUMS for each repo
6. Optionally creates MANIFEST.json with all hashes

## Approach 3: Per-Repository Build Scripts

### Individual Repo Builds

Each repository can be built individually using `det_build.sh`:

```bash
# Build bllvm-consensus
cd /path/to/bllvm-consensus
../commons/tools/det_build.sh --repo .

# Build bllvm-protocol (after bllvm-consensus)
cd /path/to/bllvm-protocol
../commons/tools/det_build.sh --repo . --package bllvm-protocol

# Build bllvm-node (after bllvm-protocol)
cd /path/to/bllvm-node
../commons/tools/det_build.sh --repo . --package bllvm-node

# Build bllvm-sdk
cd /path/to/bllvm-sdk
../commons/tools/det_build.sh --repo . --package bllvm-sdk

# Build governance-app
cd /path/to/governance-app
../commons/tools/det_build.sh --repo . --package governance-app
```

**What `det_build.sh` does:**
1. Uses `rust-toolchain.toml` if present
2. Sets deterministic build flags (`RUSTFLAGS`)
3. Builds with `--locked --release`
4. Generates SHA256SUMS for binaries and Cargo.lock

## Approach 4: Complete Release Chain

### Full Release Workflow

Combine all steps for a complete release:

```bash
#!/bin/bash
# Complete release chain script

set -euo pipefail

COMMONS_DIR="/path/to/BTCDecoded/commons"
BASE_DIR="/path/to/checkouts"
VERSION_TAG="v0.1.0"

# Step 1: Setup build environment
cd "$COMMONS_DIR"
./scripts/setup-build-env.sh --tag "$VERSION_TAG"

# Step 2: Build release set
./tools/build_release_set.sh \
  --base "$BASE_DIR" \
  --gov-source \
  --gov-docker \
  --manifest "$COMMONS_DIR/artifacts"

# Step 3: Collect artifacts
./scripts/collect-artifacts.sh

# Step 4: Create release package
./scripts/create-release.sh "$VERSION_TAG"

# Step 5: Verify versions
./scripts/verify-versions.sh

echo "Release $VERSION_TAG complete!"
echo "Artifacts: $COMMONS_DIR/artifacts/"
```

## Detailed Script Reference

### `build.sh` - Unified Build Script

**Location:** `commons/build.sh`

**Purpose:** Build all repos using local path dependencies

**Usage:**
```bash
./build.sh [--mode dev|release]
```

**Features:**
- ✅ Checks Rust toolchain (1.70+)
- ✅ Verifies all repos exist
- ✅ Topological sort for dependency order
- ✅ Collects binaries automatically
- ✅ Colored output for status

**Output:**
- Binaries in `artifacts/binaries/`
- Build logs in `/tmp/<repo>-build.log`

### `build_release_set.sh` - Release Set Builder

**Location:** `commons/tools/build_release_set.sh`

**Purpose:** Build a specific release set from `versions.toml`

**Usage:**
```bash
./tools/build_release_set.sh \
  --base /path/to/checkouts \
  [--gov-source] \
  [--gov-docker] \
  [--manifest /path/to/output]
```

**Features:**
- ✅ Reads `versions.toml` for version tags
- ✅ Checks out each repo to specific tag
- ✅ Uses deterministic builds
- ✅ Generates SHA256SUMS per repo
- ✅ Optional manifest generation

**Output:**
- `SHA256SUMS` in each repo directory
- `MANIFEST.json` (if `--manifest` specified)
- `IMAGE_TAG.txt` for Docker image (if `--gov-docker`)

### `det_build.sh` - Deterministic Build Wrapper

**Location:** `commons/tools/det_build.sh`

**Purpose:** Build a single repo deterministically

**Usage:**
```bash
./tools/det_build.sh \
  --repo /path/to/repo \
  [--features "feature1,feature2"] \
  [--package name]
```

**Features:**
- ✅ Uses `rust-toolchain.toml` if present
- ✅ Deterministic build flags
- ✅ Generates SHA256SUMS
- ✅ `--locked` flag for reproducibility

**Output:**
- Built binaries in `target/release/`
- `SHA256SUMS` in repo root

### `collect-artifacts.sh` - Artifact Collector

**Location:** `commons/scripts/collect-artifacts.sh`

**Purpose:** Collect all binaries into release archives

**Usage:**
```bash
./scripts/collect-artifacts.sh [platform]
```

**Features:**
- ✅ Collects binaries from all repos
- ✅ Generates SHA256SUMS
- ✅ Creates `.tar.gz` and `.zip` archives
- ✅ Platform-specific naming

**Output:**
- `artifacts/binaries/` - All binaries
- `artifacts/SHA256SUMS` - Checksums
- `artifacts/bitcoin-commons-bllvm-<platform>.tar.gz`
- `artifacts/bitcoin-commons-bllvm-<platform>.zip`

### `create-release.sh` - Release Package Creator

**Location:** `commons/scripts/create-release.sh`

**Purpose:** Create unified release package with notes

**Usage:**
```bash
./scripts/create-release.sh <version-tag>
```

**Features:**
- ✅ Generates RELEASE_NOTES.md
- ✅ Includes installation instructions
- ✅ Verification instructions
- ✅ Links to documentation

**Output:**
- `artifacts/RELEASE_NOTES.md`

### `setup-build-env.sh` - Environment Setup

**Location:** `commons/scripts/setup-build-env.sh`

**Purpose:** Setup build environment (clone/update repos)

**Usage:**
```bash
./scripts/setup-build-env.sh [--tag <version-tag>]
```

**Features:**
- ✅ Clones all required repos
- ✅ Checks out specific tag if provided
- ✅ Updates existing checkouts

## Complete Example: Local Release Build

```bash
#!/bin/bash
# Complete local release build example

set -euo pipefail

# Configuration
COMMONS_DIR="$HOME/src/BTCDecoded/commons"
BASE_DIR="$HOME/src/BTCDecoded/checkouts"
VERSION_TAG="v0.1.0"

# Step 1: Setup environment
echo "=== Step 1: Setting up build environment ==="
cd "$COMMONS_DIR"
mkdir -p "$BASE_DIR"
./scripts/setup-build-env.sh --tag "$VERSION_TAG" || {
  # If setup fails, manually clone repos
  for repo in bllvm-consensus bllvm-protocol bllvm-node bllvm-sdk governance-app; do
    if [ ! -d "$BASE_DIR/$repo" ]; then
      git clone "https://github.com/BTCDecoded/$repo.git" "$BASE_DIR/$repo"
    fi
  done
}

# Step 2: Build release set
echo "=== Step 2: Building release set ==="
./tools/build_release_set.sh \
  --base "$BASE_DIR" \
  --gov-source \
  --gov-docker \
  --manifest "$COMMONS_DIR/artifacts"

# Step 3: Collect artifacts
echo "=== Step 3: Collecting artifacts ==="
./scripts/collect-artifacts.sh linux-x86_64

# Step 4: Create release package
echo "=== Step 4: Creating release package ==="
./scripts/create-release.sh "$VERSION_TAG"

# Step 5: Verify versions
echo "=== Step 5: Verifying versions ==="
./scripts/verify-versions.sh

# Summary
echo ""
echo "=== Release Build Complete ==="
echo "Version: $VERSION_TAG"
echo "Artifacts: $COMMONS_DIR/artifacts/"
echo ""
echo "Files created:"
ls -lh "$COMMONS_DIR/artifacts/"
```

## CI/CD Integration

### Using GitHub Actions

The `release_orchestrator.yml` workflow handles everything:

```yaml
# Trigger from GitHub UI or CLI
gh workflow run release_orchestrator.yml
```

**Workflow chain:**
1. `read-versions` → Reads `versions.toml`
2. `verify-consensus` → Verifies bllvm-consensus
3. `build-bllvm-protocol` → Builds bllvm-protocol
4. `build-bllvm-node` → Builds bllvm-node
5. `build-bllvm-sdk` → Builds bllvm-sdk
6. `build-governance-app-image` → Builds Docker image
7. `deploy-signal` → Signals deployment

### Custom Workflow

You can create custom workflows that call the reusable workflows:

```yaml
name: Custom Release

on:
  workflow_dispatch:
    inputs:
      version_tag:
        required: true
        type: string

jobs:
  build-all:
    uses: BTCDecoded/commons/.github/workflows/build_lib_cached.yml
    with:
      repo: bllvm-consensus
      ref: ${{ inputs.version_tag }}
      use_cache: true
  
  # Chain more builds...
```

## Version Coordination

### `versions.toml` - Single Source of Truth

```toml
bllvm-consensus = "v0.1.0"
bllvm-protocol = "v0.1.0"
bllvm-node = "v0.1.0"
bllvm-sdk = "v0.1.0"
governance-app = "v0.1.0"
```

All build scripts read from this file to determine which versions to build together.

## Artifact Collection

### Binaries Collected

- **bllvm-node**: `bllvm-node`
- **bllvm-sdk**: `bllvm-keygen`, `bllvm-sign`, `bllvm-verify`
- **governance-app**: `governance-app`, `key-manager`, `test-content-hash*`

### Libraries (No Binaries)

- **bllvm-consensus**: Library only
- **bllvm-protocol**: Library only

## Troubleshooting

### Build Order Issues

If dependencies aren't met:
1. Check `versions.toml` for compatible versions
2. Verify all repos are checked out to correct tags
3. Run `./scripts/verify-versions.sh`

### Missing Binaries

If binaries aren't collected:
1. Check `target/release/` in each repo
2. Verify binary names match `BINARIES` mapping
3. Check build logs in `/tmp/<repo>-build.log`

### Version Mismatches

Run verification:
```bash
./scripts/verify-versions.sh
```

This checks that all repos have compatible versions.

## Best Practices

1. **Always use `versions.toml`** for release builds
2. **Use `--locked` flag** for deterministic builds
3. **Verify versions** before building
4. **Generate SHA256SUMS** for all artifacts
5. **Use cached workflows** in CI/CD for speed
6. **Test locally** before triggering CI/CD

## See Also

- `BUILD_SYSTEM.md` - Build system documentation
- `BUILD_POLICY.md` - Build policy and guidelines
- `WORKFLOW_METHODOLOGY.md` - Workflow methodology
- `scripts/README.md` - Script documentation

