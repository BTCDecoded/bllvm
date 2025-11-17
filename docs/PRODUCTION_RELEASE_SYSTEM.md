# Production Release System

## Overview

The production release system (`release_prod.yml`) creates unified releases by intelligently reusing existing component releases when available, and only building what's necessary. It includes hash verification and provenance tracking through build manifests.

## Key Features

### 1. Smart Build Selection
- **Checks existing releases**: Queries GitHub to see if component releases exist at locked versions
- **Downloads artifacts**: Reuses existing releases instead of rebuilding (faster, more reliable)
- **Builds only when needed**: Only builds components that don't have existing releases
- **Uses locked versions**: Reads `versions.toml` to get exact version tags for each component

### 2. Hash Verification
- **Verifies downloaded artifacts**: Automatically verifies SHA256SUMS for downloaded binaries
- **Validates checksums**: Ensures integrity of all artifacts before packaging
- **Fails on mismatch**: Stops release process if any hash verification fails

### 3. Provenance Tracking
- **Component manifests**: Generates JSON manifest for each component with:
  - Version and commit hash
  - Binary hash and size
  - Source repository URL
  - Build metadata
- **Integration manifest**: Creates unified manifest (`release-manifest.json`) listing:
  - All component versions included
  - Package hash and size
  - Verification instructions
  - Component provenance chain

### 4. Platform Selection
- **Linux only**: Build/download Linux artifacts
- **Windows only**: Build/download Windows artifacts  
- **Both**: Build/download for both platforms

## Workflow

### Step 1: Determine Requirements
- Reads `versions.toml` to get locked versions
- Checks GitHub API for each component release
- Outputs JSON with build requirements per component

### Step 2: Download Existing Artifacts
- Downloads binaries, SHA256SUMS, and release notes for components with existing releases
- Verifies checksums automatically
- Places artifacts in `artifacts/` directory

### Step 3: Checkout Repositories
- Checks out all repos at locked versions (needed for dependencies)
- Ensures dependency resolution works even if artifacts are downloaded

### Step 4: Build Missing Components
- Builds only components that don't have existing releases
- Uses existing `build.sh` system (fully compatible)
- Runs tests for newly built components

### Step 5: Collect Artifacts
- Collects binaries from both downloads and builds
- Generates SHA256SUMS files
- Creates platform-specific archives

### Step 6: Generate Manifests
- Creates component manifests for all components (downloaded + built)
- Generates integration manifest with full provenance
- Includes commit hashes, binary hashes, and source URLs

### Step 7: Validate & Release
- Validates all required artifacts exist
- Creates GitHub production release
- Includes binaries, checksums, manifests, and release notes

## Scripts

### `check-release-exists.sh`
Checks if a GitHub release exists for a repository at a specific version.

**Usage:**
```bash
./check-release-exists.sh <repo> <version_tag> [org]
```

**Returns:**
- Exit code 0: Release exists (outputs release ID)
- Exit code 1: Release doesn't exist
- Exit code 2: Error

### `download-release-artifacts.sh`
Downloads artifacts from an existing GitHub release and verifies checksums.

**Usage:**
```bash
./download-release-artifacts.sh <repo> <version_tag> <output_dir> [org] [platform]
```

**Features:**
- Downloads binaries, SHA256SUMS, and release notes
- Automatically verifies checksums
- Platform-aware (linux/windows)

### `determine-build-requirements.sh`
Analyzes `versions.toml` and determines which repos need building vs which can use existing releases.

**Usage:**
```bash
./determine-build-requirements.sh [versions.toml] [platform]
```

**Output:** JSON with build requirements per repo

### `generate-component-manifest.sh`
Generates build manifest for a component repository.

**Usage:**
```bash
./generate-component-manifest.sh <repo> <version_tag> <commit_hash> <platform> <output_file> [--artifacts-dir DIR]
```

**Output:** JSON manifest with component metadata

### `generate-integration-manifest.sh`
Generates integration manifest for unified release.

**Usage:**
```bash
./generate-integration-manifest.sh <version_tag> <artifacts_dir> <output_file> [component_manifests...]
```

**Output:** JSON manifest with all component versions and package info

## Manifest Formats

### Component Manifest
```json
{
  "component": "bllvm-node",
  "version": "v0.1.0",
  "commit": "abc123...",
  "build_date": "2025-11-16T12:00:00Z",
  "platform": "linux-x86_64",
  "source": {
    "repo": "BTCDecoded/bllvm-node",
    "tag": "v0.1.0",
    "commit": "abc123...",
    "url": "https://github.com/BTCDecoded/bllvm-node/releases/tag/v0.1.0"
  },
  "binary": {
    "name": "bllvm-node",
    "hash": "def456...",
    "size": 12345678
  },
  "reproducible": false,
  "build_method": "github-actions"
}
```

### Integration Manifest
```json
{
  "bllvm_release": "v0.1.0",
  "release_date": "2025-11-16T12:00:00Z",
  "integration_commit": "xyz789...",
  "components": {
    "bllvm-consensus": {
      "version": "v0.1.0",
      "commit": "abc123...",
      "source": {...},
      "binary": {...}
    },
    "bllvm-node": {
      "version": "v0.1.0",
      "commit": "def456...",
      "source": {...},
      "binary": {...}
    }
  },
  "package": {
    "name": "bllvm-v0.1.0-linux-x86_64.tar.gz",
    "hash": "final789...",
    "size": 45678901
  },
  "verification": {
    "checksums_file": "SHA256SUMS-*",
    "instructions": "Verify checksums: sha256sum -c SHA256SUMS-*"
  }
}
```

## Usage

### Via GitHub Actions UI
1. Go to Actions → Create Production Release
2. Enter version tag (e.g., `v0.1.0`)
3. Select platform (linux/windows/both)
4. Run workflow

### Via GitHub CLI
```bash
gh workflow run release_prod.yml \
  -f version_tag=v0.1.0 \
  -f platform=both
```

## Benefits

1. **Faster releases**: Reuses existing component releases instead of rebuilding
2. **More reliable**: Uses already-tested and released components
3. **Full provenance**: Complete traceability of every component version
4. **Hash verification**: Ensures integrity of all artifacts
5. **Compatible**: Works with existing build system without refactoring

## Compatibility

- ✅ Fully compatible with existing `build.sh` system
- ✅ Works with current `collect-artifacts.sh` script
- ✅ Uses existing `versions.toml` format
- ✅ No changes required to component repositories

## Future Enhancements (Phase 2+)

- Docker-based reproducible builds
- Full build manifest with Docker image hashes
- Reproducible build verification
- Governance signature integration
- Multi-platform support expansion

