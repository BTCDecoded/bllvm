# Workflow Options Consistency Summary

**Date:** 2025-01-XX  
**Status:** Standardized

## Changes Made

### 1. Added Standard Options to All Workflows

#### All Workflows Now Have:
- ✅ `timeout_minutes` - Configurable timeout (number, with sensible defaults)
- ✅ `permissions` block - Explicit permissions for security
- ✅ `env` block - Consistent environment variables
- ✅ `use_cache` - For cached workflows (boolean, default: true)

#### Build Workflows (`build_lib.yml`, `build_lib_cached.yml`):
- ✅ `repo` - Repository name (required)
- ✅ `ref` - Git reference (required)
- ✅ `package` - Cargo package (optional)
- ✅ `features` - Cargo features (optional)
- ✅ `release` - Release mode (optional, default: true)
- ✅ `verify_deterministic` - Verify deterministic builds (optional, default: false)
- ✅ `timeout_minutes` - Job timeout (optional, default: 60)
- ✅ `use_cache` - Use local caching (cached version only, optional, default: true)

#### Verification Workflows (`verify_consensus.yml`, `verify_consensus_cached.yml`):
- ✅ `repo` - Repository name (optional, default: consensus-proof)
- ✅ `ref` - Git reference (required)
- ✅ `kani` - Run Kani verification (optional, default: true)
- ✅ `timeout_minutes` - Job timeout (optional, default: 120)
- ✅ `use_cache` - Use local caching (cached version only, optional, default: true)

#### Docker Workflows (`build_docker.yml`):
- ✅ `repo` - Repository name (required)
- ✅ `ref` - Git reference (required)
- ✅ `context` - Docker build context (optional, default: ".")
- ✅ `image_name` - Docker image name (optional, default: "governance-app")
- ✅ `push` - Push to registry (optional, default: false)
- ✅ `tag` - Docker image tag (required)
- ✅ `timeout_minutes` - Job timeout (optional, default: 30)
- ✅ `use_cache` - Use local caching for source (optional, default: true)

### 2. Standardized Environment Variables

All workflows now have consistent `env` blocks:

#### Build Workflows:
```yaml
env:
  RUST_BACKTRACE: '1'
  CARGO_TERM_COLOR: 'always'
  RUSTFLAGS: '-C debuginfo=0 -C link-arg=-s'
  CI: 'true'
  CARGO_INCREMENTAL: '1'
```

#### Verification Workflows:
```yaml
env:
  RUST_BACKTRACE: '1'
  CARGO_TERM_COLOR: 'always'
  CI: 'true'
  CARGO_INCREMENTAL: '1'
```

#### Docker Workflows:
```yaml
env:
  CI: 'true'
  DOCKER_BUILDKIT: '1'
```

### 3. Standardized Permissions

All workflows now have explicit `permissions` blocks:

#### Build/Verification Workflows:
```yaml
permissions:
  contents: read
  actions: read
```

#### Docker Workflows:
```yaml
permissions:
  contents: read
  packages: write
  actions: read
```

### 4. Updated Release Orchestrator

The `release_orchestrator.yml` now:
- ✅ Uses cached workflows (`build_lib_cached.yml`, `verify_consensus_cached.yml`)
- ✅ Passes all available options explicitly
- ✅ Sets appropriate timeouts per job type
- ✅ Enables caching for all jobs
- ✅ Sets `verify_deterministic: false` (can be enabled for releases if needed)

### 5. Enhanced Docker Workflow

The `build_docker.yml` now:
- ✅ Has disk space checks
- ✅ Supports local caching for source builds
- ✅ Has cache cleanup management
- ✅ Uses Docker BuildKit cache (GitHub Actions cache)
- ✅ Has proper timeout management

## Option Usage Matrix

| Workflow | timeout_minutes | use_cache | permissions | env | release_orchestrator |
|----------|----------------|-----------|-------------|-----|---------------------|
| build_lib.yml | ✅ | ❌ | ✅ | ✅ | ✅ (via cached) |
| build_lib_cached.yml | ✅ | ✅ | ✅ | ✅ | ✅ |
| verify_consensus.yml | ✅ | ❌ | ✅ | ✅ | ✅ (via cached) |
| verify_consensus_cached.yml | ✅ | ✅ | ✅ | ✅ | ✅ |
| build_docker.yml | ✅ | ✅ | ✅ | ✅ | ✅ |

## Default Timeouts

- **Build workflows**: 60 minutes (default)
- **Reference node build**: 90 minutes (larger project)
- **Verification workflows**: 120 minutes (Kani can be slow)
- **Docker builds**: 30 minutes (default)

## Benefits

1. **Consistency**: All workflows follow the same patterns
2. **Flexibility**: Options can be customized per call
3. **Security**: Explicit permissions reduce attack surface
4. **Performance**: Caching enabled by default
5. **Reliability**: Timeouts prevent hung jobs
6. **Observability**: Consistent environment variables aid debugging

## Migration Notes

- ✅ All workflows now standardized
- ✅ Release orchestrator updated to use cached workflows
- ✅ All options explicitly passed
- ✅ No breaking changes (all options have defaults)

## See Also

- `WORKFLOW_OPTIONS.md` - Detailed options documentation
- `WORKFLOW_ENHANCEMENTS.md` - Enhancement details
- `WORKFLOW_PATTERNS_ANALYSIS.md` - Pattern analysis

