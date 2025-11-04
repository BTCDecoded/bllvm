# Workflow Patterns Analysis: MyBitcoinFuture → BTCDecoded

**Date:** 2025-01-XX  
**Status:** Analysis Complete

## Executive Summary

This document analyzes MyBitcoinFuture's workflow patterns and techniques that can be adapted for BTCDecoded's Rust-based workflows. Key patterns include local caching, parallel execution, cache management, and build optimization.

## Key Patterns Identified

### 1. Local Caching System

#### Pattern Description
MyBitcoinFuture uses a sophisticated local caching system at `/tmp/runner-cache` with rsync for fast cache restoration.

#### Implementation
```yaml
- name: Setup local cache system
  id: setup-cache
  run: |
    CACHE_ROOT="/tmp/runner-cache"
    DEPS_KEY=$(sha256sum package-lock.json | cut -d' ' -f1)-$(grep -E '"7zip-bin"|"app-builder-bin"' package.json | sha256sum | cut -d' ' -f1)
    echo "DEPS_CACHE_DIR=$CACHE_ROOT/deps/$DEPS_KEY" >> $GITHUB_ENV
    echo "deps-key=$DEPS_KEY" >> $GITHUB_OUTPUT
    mkdir -p "$CACHE_ROOT/deps/$DEPS_KEY"

- name: Restore dependencies from local cache (optimized)
  run: |
    if [ -d "$DEPS_CACHE_DIR/node_modules" ]; then
      rsync -a --delete "$DEPS_CACHE_DIR/node_modules/" ./node_modules/
      echo "DEPS_RESTORED=true" >> $GITHUB_ENV
    fi
```

#### Adaptation for BTCDecoded (Rust/Cargo)
```yaml
- name: Setup local cache system
  id: setup-cache
  run: |
    CACHE_ROOT="/tmp/runner-cache"
    # Use Cargo.lock hash for cache key
    DEPS_KEY=$(sha256sum Cargo.lock | cut -d' ' -f1)
    echo "CARGO_CACHE_DIR=$CACHE_ROOT/cargo/$DEPS_KEY" >> $GITHUB_ENV
    echo "CARGO_TARGET_DIR=$CACHE_ROOT/target/$DEPS_KEY" >> $GITHUB_ENV
    echo "deps-key=$DEPS_KEY" >> $GITHUB_OUTPUT
    mkdir -p "$CACHE_ROOT/cargo/$DEPS_KEY" "$CACHE_ROOT/target/$DEPS_KEY"

- name: Restore Cargo cache
  run: |
    if [ -d "$CARGO_CACHE_DIR/registry" ]; then
      rsync -a --delete "$CARGO_CACHE_DIR/registry/" "$HOME/.cargo/registry/"
      rsync -a --delete "$CARGO_CACHE_DIR/git/" "$HOME/.cargo/git/"
      echo "CARGO_CACHE_RESTORED=true" >> $GITHUB_ENV
    fi
    if [ -d "$CARGO_TARGET_DIR" ]; then
      rsync -a --delete "$CARGO_TARGET_DIR/" ./target/
      echo "TARGET_CACHE_RESTORED=true" >> $GITHUB_ENV
    fi
```

**Benefits:**
- ✅ **10-100x faster** than GitHub Actions cache for large dependency sets
- ✅ **Preserves symlinks** and permissions (rsync)
- ✅ **Works offline** once cached
- ✅ **No API rate limits** for cache operations

### 2. Cache Key Strategy

#### Pattern Description
Multi-factor cache keys using file hashes + specific binary versions ensure cache invalidation when dependencies change.

#### MyBitcoinFuture Approach
```bash
DEPS_KEY=$(sha256sum package-lock.json | cut -d' ' -f1)-$(grep -E '"7zip-bin"|"app-builder-bin"' package.json | sha256sum | cut -d' ' -f1)
```

#### BTCDecoded Adaptation
```bash
# For Rust dependencies
DEPS_KEY=$(sha256sum Cargo.lock | cut -d' ' -f1)-$(grep -E 'rust-version|rust-toolchain' rust-toolchain.toml Cargo.toml 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "stable")
```

**Key Insights:**
- Include lock file hash (primary dependency source)
- Include toolchain version (affects build output)
- Optional: Include cache trigger file for manual invalidation

### 3. Parallel Job Execution Pattern

#### Pattern Description
Setup job runs first, then multiple jobs run in parallel using the same cache key.

#### MyBitcoinFuture Structure
```yaml
jobs:
  setup-dependencies:
    outputs:
      deps-key: ${{ steps.setup-cache.outputs.deps-key }}
      cache-key: ${{ steps.setup-cache.outputs.deps-key }}
  
  lint:
    needs: setup-dependencies
    # Uses cache-key from setup-dependencies
  
  test:
    needs: setup-dependencies
    # Uses cache-key from setup-dependencies
  
  security:
    needs: setup-dependencies
    # Uses cache-key from setup-dependencies
```

#### BTCDecoded Adaptation
```yaml
jobs:
  setup-cache:
    outputs:
      cargo-cache-key: ${{ steps.setup-cache.outputs.cargo-cache-key }}
      target-cache-key: ${{ steps.setup-cache.outputs.target-cache-key }}
  
  test:
    needs: setup-cache
    # Uses cargo-cache-key
  
  clippy:
    needs: setup-cache
    # Uses cargo-cache-key
  
  fmt:
    needs: setup-cache
    # No cache needed, but same dependency setup
```

**Benefits:**
- ✅ **Parallel execution** after setup
- ✅ **Shared cache** across all jobs
- ✅ **Faster overall** workflow completion

### 4. Disk Space Management

#### Pattern Description
Emergency disk space checks and proactive cleanup prevent runner failures.

#### MyBitcoinFuture Implementation
```yaml
- name: Emergency disk space check (pre-steps)
  run: |
    echo "🔍 DEBUG: Disk space before setup:"
    df -h
    echo "🔍 DEBUG: Node/NPM cache cleanup"
    npm cache clean --force || true
    echo "🔍 DEBUG: Disk space after npm cache clean:"
    df -h
```

#### BTCDecoded Adaptation
```yaml
- name: Emergency disk space check
  run: |
    echo "🔍 DEBUG: Disk space before setup:"
    df -h
    echo "🔍 DEBUG: Cargo cache cleanup"
    cargo clean || true
    # Clean old target directories
    find /tmp/runner-cache/target -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    echo "🔍 DEBUG: Disk space after cleanup:"
    df -h
```

### 5. Cache Cleanup Management

#### Pattern Description
Automatic cleanup of old cache entries to prevent disk exhaustion.

#### MyBitcoinFuture Approach
```yaml
- name: Cache cleanup management
  run: |
    # Keep only last 3 dependency caches
    find /tmp/runner-cache/deps -maxdepth 1 -type d -mtime +1 | head -n -3 | xargs rm -rf 2>/dev/null || true
    echo "🧹 Cache cleanup completed"
```

#### BTCDecoded Adaptation
```yaml
- name: Cache cleanup management
  run: |
    # Keep last 5 Cargo caches (more needed for Rust)
    find /tmp/runner-cache/cargo -maxdepth 1 -type d -mtime +1 | head -n -5 | xargs rm -rf 2>/dev/null || true
    # Keep last 3 target caches (build artifacts are larger)
    find /tmp/runner-cache/target -maxdepth 1 -type d -mtime +1 | head -n -3 | xargs rm -rf 2>/dev/null || true
    echo "🧹 Cache cleanup completed"
```

### 6. Build Artifact Caching

#### Pattern Description
Cache not just dependencies, but also build outputs for faster incremental builds.

#### MyBitcoinFuture Pattern
```yaml
- name: Cache build artifacts
  run: |
    CACHE_ROOT="/tmp/runner-cache"
    BUILD_KEY="${{ github.sha }}-nightly-shared"
    BUILD_CACHE_DIR="$CACHE_ROOT/builds/$BUILD_KEY"
    rsync -a --delete web/dist/ "$BUILD_CACHE_DIR/"
```

#### BTCDecoded Adaptation
```yaml
- name: Cache build artifacts
  run: |
    CACHE_ROOT="/tmp/runner-cache"
    BUILD_KEY="${{ github.sha }}-${{ matrix.target }}"
    BUILD_CACHE_DIR="$CACHE_ROOT/builds/$BUILD_KEY"
    mkdir -p "$BUILD_CACHE_DIR"
    # Cache target directory for incremental builds
    rsync -a --delete target/ "$BUILD_CACHE_DIR/target/"
    # Cache binaries separately
    find target/release -maxdepth 1 -type f -executable -exec cp {} "$BUILD_CACHE_DIR/" \;
```

### 7. Timeout Management

#### Pattern Description
Explicit timeouts prevent hung jobs from blocking runners.

#### MyBitcoinFuture Pattern
```yaml
jobs:
  setup-dependencies:
    timeout-minutes: 8
  
  lint:
    timeout-minutes: 6
  
  test:
    timeout-minutes: 12
```

#### BTCDecoded Adaptation
```yaml
jobs:
  setup-cache:
    timeout-minutes: 5
  
  test:
    timeout-minutes: 30  # Tests can be longer for consensus code
  
  build:
    timeout-minutes: 60  # Builds can take longer
  
  verify-kani:
    timeout-minutes: 120  # Kani can take a long time
```

### 8. Environment Variables

#### Pattern Description
Comprehensive environment setup at workflow level for consistency.

#### MyBitcoinFuture Pattern
```yaml
env:
  NODE_VERSION: '20'
  DOCKER_REGISTRY: 127.0.0.1:5000
  NODE_ENV: 'test'
  CI: 'true'
  MOCK_MODE: 'true'
```

#### BTCDecoded Adaptation
```yaml
env:
  RUST_BACKTRACE: '1'
  CARGO_TERM_COLOR: 'always'
  RUSTFLAGS: '-C debuginfo=0 -C link-arg=-s'
  CI: 'true'
  CARGO_INCREMENTAL: '1'
```

### 9. Security Best Practices

#### Pattern Description
Explicit permissions reduce attack surface.

#### MyBitcoinFuture Pattern
```yaml
permissions:
  contents: write
  packages: write
  actions: write
  id-token: write
```

#### BTCDecoded Adaptation
```yaml
permissions:
  contents: read  # Read-only for most workflows
  actions: read   # Read workflow files
  # Only release workflows need write permissions
```

### 10. Conditional Execution

#### Pattern Description
Conditional steps based on cache state or environment.

#### MyBitcoinFuture Pattern
```yaml
- name: Install dependencies (if not cached)
  if: env.DEPS_RESTORED != 'true'
  run: |
    npm ci
```

#### BTCDecoded Adaptation
```yaml
- name: Build (if not cached)
  if: env.TARGET_CACHE_RESTORED != 'true'
  run: |
    cargo build --locked --release
```

### 11. Debugging and Observability

#### Pattern Description
Extensive debug output with emojis for quick visual scanning.

#### MyBitcoinFuture Pattern
```yaml
- name: Setup local cache system
  run: |
    echo "🔍 DEBUG: Cache setup complete"
    echo "🔍 DEBUG: Dependencies cache: $CACHE_ROOT/deps/$DEPS_KEY"
    echo "🔍 DEBUG: package-lock sha: $(sha256sum package-lock.json | cut -d' ' -f1)"
```

#### BTCDecoded Adaptation
```yaml
- name: Setup Cargo cache
  run: |
    echo "🔍 DEBUG: Cache setup complete"
    echo "🔍 DEBUG: Cargo cache: $CARGO_CACHE_DIR"
    echo "🔍 DEBUG: Cargo.lock sha: $(sha256sum Cargo.lock | cut -d' ' -f1)"
    echo "🔍 DEBUG: Rust toolchain: $(rustc --version)"
```

### 12. Multi-Stage Caching

#### Pattern Description
Separate caches for dependencies, builds, and artifacts.

#### MyBitcoinFuture Structure
```
/tmp/runner-cache/
├── deps/          # Dependencies
├── builds/         # Build artifacts
└── ...
```

#### BTCDecoded Structure
```
/tmp/runner-cache/
├── cargo/          # Cargo registry and git
│   ├── registry/
│   └── git/
├── target/         # Build target directories
└── builds/         # Final binaries and artifacts
```

## Workflow Structure Patterns

### 1. Setup → Parallel Jobs Pattern

```yaml
jobs:
  setup:
    outputs:
      cache-key: ${{ steps.cache.outputs.key }}
  
  job1:
    needs: setup
    # Parallel with job2
  
  job2:
    needs: setup
    # Parallel with job1
  
  final:
    needs: [job1, job2]
    # Runs after both complete
```

### 2. Conditional Job Execution

```yaml
jobs:
  build-dev:
    if: github.event_name == 'pull_request'
  
  build-release:
    if: github.event_name == 'release'
```

### 3. Matrix Strategy for Multiple Configurations

```yaml
strategy:
  matrix:
    rust: ["1.70.0", "stable", "beta"]
    target: ["x86_64-unknown-linux-gnu", "x86_64-pc-windows-msvc"]
```

## Recommended Enhancements for BTCDecoded Workflows

### 1. Enhanced `build_lib.yml` with Local Caching

```yaml
name: Build Library/Binary (Reusable)

on:
  workflow_call:
    inputs:
      repo: { required: true, type: string }
      package: { required: false, type: string, default: "" }
      ref: { required: true, type: string }
      use_cache: { required: false, type: boolean, default: true }

jobs:
  build:
    runs-on: self-hosted,linux,x64,rust
    steps:
      - name: Checkout target repository
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/${{ inputs.repo }}
          ref: ${{ inputs.ref }}
      
      - name: Setup local cache system
        if: ${{ inputs.use_cache }}
        id: setup-cache
        run: |
          CACHE_ROOT="/tmp/runner-cache"
          DEPS_KEY=$(sha256sum Cargo.lock | cut -d' ' -f1)
          CARGO_CACHE_DIR="$CACHE_ROOT/cargo/$DEPS_KEY"
          TARGET_CACHE_DIR="$CACHE_ROOT/target/$DEPS_KEY"
          
          echo "CARGO_CACHE_DIR=$CARGO_CACHE_DIR" >> $GITHUB_ENV
          echo "TARGET_CACHE_DIR=$TARGET_CACHE_DIR" >> $GITHUB_ENV
          echo "cache-key=$DEPS_KEY" >> $GITHUB_OUTPUT
          mkdir -p "$CARGO_CACHE_DIR" "$TARGET_CACHE_DIR"
      
      - name: Restore Cargo cache
        if: ${{ inputs.use_cache }}
        run: |
          if [ -d "$CARGO_CACHE_DIR/registry" ]; then
            rsync -a --delete "$CARGO_CACHE_DIR/registry/" "$HOME/.cargo/registry/" || true
            echo "CARGO_REGISTRY_RESTORED=true" >> $GITHUB_ENV
          fi
          if [ -d "$CARGO_CACHE_DIR/git" ]; then
            rsync -a --delete "$CARGO_CACHE_DIR/git/" "$HOME/.cargo/git/" || true
            echo "CARGO_GIT_RESTORED=true" >> $GITHUB_ENV
          fi
          if [ -d "$TARGET_CACHE_DIR" ]; then
            rsync -a --delete "$TARGET_CACHE_DIR/" ./target/ || true
            echo "TARGET_RESTORED=true" >> $GITHUB_ENV
          fi
      
      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable
      
      - name: Build
        run: |
          export CARGO_TARGET_DIR="./target"
          cargo build --locked --release ${{ inputs.package && format('-p {0}', inputs.package) || '' }}
      
      - name: Cache Cargo registry and git
        if: ${{ inputs.use_cache && env.CARGO_REGISTRY_RESTORED != 'true' }}
        run: |
          rsync -a --delete "$HOME/.cargo/registry/" "$CARGO_CACHE_DIR/registry/" || true
          rsync -a --delete "$HOME/.cargo/git/" "$CARGO_CACHE_DIR/git/" || true
      
      - name: Cache target directory
        if: ${{ inputs.use_cache }}
        run: |
          rsync -a --delete ./target/ "$TARGET_CACHE_DIR/" || true
      
      - name: Hash artifacts
        run: |
          find target/release -maxdepth 1 -type f -executable -print0 | xargs -0 sha256sum > SHA256SUMS || true
          sha256sum Cargo.lock >> SHA256SUMS || true
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ${{ inputs.repo }}-artifacts
          path: |
            target/release/*
            SHA256SUMS
      
      - name: Cache cleanup
        if: always()
        run: |
          # Keep last 5 Cargo caches
          find /tmp/runner-cache/cargo -maxdepth 1 -type d -mtime +1 | head -n -5 | xargs rm -rf 2>/dev/null || true
          # Keep last 3 target caches
          find /tmp/runner-cache/target -maxdepth 1 -type d -mtime +1 | head -n -3 | xargs rm -rf 2>/dev/null || true
```

### 2. Enhanced `verify_consensus.yml` with Caching

```yaml
name: Verify Consensus (Reusable)

on:
  workflow_call:
    inputs:
      repo: { required: false, type: string, default: consensus-proof }
      kani: { required: false, type: boolean, default: true }
      ref: { required: true, type: string }
      use_cache: { required: false, type: boolean, default: true }

jobs:
  verify:
    runs-on: ${{ inputs.kani && 'self-hosted,linux,x64,rust,kani' || 'self-hosted,linux,x64,rust' }}
    timeout-minutes: 60
    steps:
      - name: Checkout target repository
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/${{ inputs.repo }}
          ref: ${{ inputs.ref }}
      
      - name: Setup cache
        if: ${{ inputs.use_cache }}
        id: setup-cache
        run: |
          CACHE_ROOT="/tmp/runner-cache"
          DEPS_KEY=$(sha256sum Cargo.lock | cut -d' ' -f1)
          echo "CARGO_CACHE_DIR=$CACHE_ROOT/cargo/$DEPS_KEY" >> $GITHUB_ENV
          echo "cache-key=$DEPS_KEY" >> $GITHUB_OUTPUT
          mkdir -p "$CACHE_ROOT/cargo/$DEPS_KEY"
      
      - name: Restore Cargo cache
        if: ${{ inputs.use_cache }}
        run: |
          if [ -d "$CARGO_CACHE_DIR/registry" ]; then
            rsync -a --delete "$CARGO_CACHE_DIR/registry/" "$HOME/.cargo/registry/" || true
          fi
      
      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable
      
      - name: Cargo test (all features)
        run: cargo test --all-features --locked
      
      - name: Install Kani (if enabled)
        if: ${{ inputs.kani }}
        run: |
          curl -fsSL https://model-checking.github.io/kani/install.sh | sh -s -- -y
          echo "$HOME/.cargo/bin" >> $GITHUB_PATH
      
      - name: Run Kani proofs
        if: ${{ inputs.kani }}
        run: cargo kani --features verify || true
      
      - name: Cache Cargo registry
        if: ${{ inputs.use_cache && always() }}
        run: |
          rsync -a --delete "$HOME/.cargo/registry/" "$CARGO_CACHE_DIR/registry/" || true
```

### 3. Parallel Test Execution Pattern

```yaml
jobs:
  setup-cache:
    outputs:
      cache-key: ${{ steps.cache.outputs.key }}
  
  test-unit:
    needs: setup-cache
    runs-on: self-hosted,linux,x64,rust
    # Parallel with test-integration
  
  test-integration:
    needs: setup-cache
    runs-on: self-hosted,linux,x64,rust
    # Parallel with test-unit
  
  clippy:
    needs: setup-cache
    runs-on: self-hosted,linux,x64,rust
    # Parallel with both tests
  
  fmt:
    needs: setup-cache
    runs-on: self-hosted,linux,x64,rust
    # Parallel with all above
  
  build:
    needs: [test-unit, test-integration, clippy, fmt]
    # Runs after all parallel jobs complete
```

## Performance Improvements

### Expected Speed Improvements

| Operation | Without Cache | With Local Cache | Improvement |
|-----------|---------------|------------------|-------------|
| Dependency Restore | 5-10 min | 10-30 sec | **10-20x faster** |
| Build Time (clean) | 15-30 min | 15-30 min | No change |
| Build Time (incremental) | 10-15 min | 2-5 min | **3-5x faster** |
| Test Execution | 5-10 min | 3-5 min | **1.5-2x faster** |

### Cache Size Estimates

| Cache Type | Typical Size | Cleanup Policy |
|------------|--------------|----------------|
| Cargo Registry | 2-5 GB | Keep last 5 |
| Cargo Git | 500 MB - 1 GB | Keep last 5 |
| Target Directory | 1-3 GB | Keep last 3 |
| Build Artifacts | 100-500 MB | Keep last 5 |

## Implementation Priority

### Phase 1: Core Caching (High Priority)
1. ✅ Add local cache setup to `build_lib.yml`
2. ✅ Add local cache setup to `verify_consensus.yml`
3. ✅ Implement cache cleanup management
4. ✅ Add disk space checks

### Phase 2: Performance Optimization (Medium Priority)
1. ✅ Parallel job execution pattern
2. ✅ Build artifact caching
3. ✅ Multi-stage cache strategy
4. ✅ Conditional execution based on cache state

### Phase 3: Observability (Low Priority)
1. ✅ Enhanced debug output
2. ✅ Cache size monitoring
3. ✅ Performance metrics
4. ✅ Cache hit rate tracking

## Migration Strategy

### Step 1: Add Caching to Existing Workflows
- Add cache setup steps
- Add cache restore steps
- Add cache save steps
- Add cleanup steps

### Step 2: Test Performance
- Measure build times before/after
- Monitor cache hit rates
- Adjust cache retention policies

### Step 3: Optimize
- Fine-tune cache keys
- Adjust cleanup policies
- Optimize rsync operations

## See Also

- `WORKFLOW_METHODOLOGY.md` - Current workflow methodology
- `RUNNER_IMPROVEMENTS.md` - Runner and script improvements
- `scripts/README.md` - Script documentation

