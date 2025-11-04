# Workflow Enhancements from MyBitcoinFuture

**Date:** 2025-01-XX  
**Status:** Analysis and Templates Complete

## Summary

This document summarizes workflow patterns learned from MyBitcoinFuture and provides enhanced workflow templates with local caching for BTCDecoded.

## Key Patterns Extracted

### 1. Local Caching with rsync
- **Pattern**: `/tmp/runner-cache` with rsync for 10-100x faster cache operations
- **Benefits**: No API rate limits, works offline, preserves symlinks
- **Implementation**: Created `build_lib_cached.yml` and `verify_consensus_cached.yml`

### 2. Cache Key Strategy
- **Pattern**: Multi-factor cache keys (lock file hash + toolchain version)
- **Benefits**: Accurate cache invalidation when dependencies change
- **Adaptation**: Cargo.lock hash + rust-toolchain.toml hash

### 3. Parallel Job Execution
- **Pattern**: Setup job → parallel jobs → final job
- **Benefits**: Faster overall workflow completion
- **Status**: Already partially implemented, can be enhanced

### 4. Disk Space Management
- **Pattern**: Emergency checks and proactive cleanup
- **Benefits**: Prevents runner failures from disk exhaustion
- **Implementation**: Added to cached workflows

### 5. Cache Cleanup
- **Pattern**: Automatic cleanup of old cache entries
- **Benefits**: Prevents disk exhaustion
- **Adaptation**: Keep last 5 Cargo caches, last 3 target caches

### 6. Build Artifact Caching
- **Pattern**: Cache build outputs, not just dependencies
- **Benefits**: Faster incremental builds
- **Implementation**: Added target directory caching

### 7. Timeout Management
- **Pattern**: Explicit timeouts per job
- **Benefits**: Prevents hung jobs from blocking runners
- **Implementation**: Added appropriate timeouts

### 8. Debugging Output
- **Pattern**: Extensive debug output with emojis
- **Benefits**: Quick visual scanning of logs
- **Implementation**: Added debug output throughout

## New Workflow Files

### 1. `build_lib_cached.yml`
Enhanced version of `build_lib.yml` with:
- ✅ Local caching for Cargo registry and git
- ✅ Target directory caching for incremental builds
- ✅ Disk space checks
- ✅ Cache cleanup management
- ✅ Debug output
- ✅ Optional caching (can be disabled)

### 2. `verify_consensus_cached.yml`
Enhanced version of `verify_consensus.yml` with:
- ✅ Local caching for Cargo registry
- ✅ Target directory caching
- ✅ Disk space checks
- ✅ Cache cleanup management
- ✅ Debug output

## Usage

### Option 1: Use Cached Workflows (Recommended)
```yaml
# In release_orchestrator.yml
build-protocol-engine:
  uses: ./.github/workflows/build_lib_cached.yml
  with:
    repo: protocol-engine
    package: protocol-engine
    ref: ${{ needs.read-versions.outputs.pe }}
    use_cache: true
```

### Option 2: Gradual Migration
1. Start with non-critical workflows
2. Monitor cache hit rates
3. Measure performance improvements
4. Gradually migrate all workflows

### Option 3: A/B Testing
- Run both cached and non-cached workflows
- Compare build times
- Measure cache effectiveness

## Performance Expectations

| Scenario | Current | With Cache | Improvement |
|----------|---------|------------|-------------|
| First build (clean) | 15-30 min | 15-30 min | Same |
| Subsequent builds | 15-30 min | 2-5 min | **3-6x faster** |
| Dependency restore | 5-10 min | 10-30 sec | **10-20x faster** |
| Test execution | 5-10 min | 3-5 min | **1.5-2x faster** |

## Cache Size Management

### Recommended Cache Retention
- **Cargo Registry**: Keep last 5 (2-5 GB each)
- **Cargo Git**: Keep last 5 (500 MB - 1 GB each)
- **Target Directory**: Keep last 3 (1-3 GB each)

### Disk Space Requirements
- **Minimum**: 20 GB free space
- **Recommended**: 50+ GB free space
- **Cleanup Threshold**: 80% disk usage

## Migration Steps

1. **Test Cached Workflows**
   ```bash
   # Manually trigger cached workflow
   gh workflow run build_lib_cached.yml --ref main
   ```

2. **Monitor Performance**
   - Check cache hit rates
   - Monitor build times
   - Verify disk usage

3. **Update Release Orchestrator**
   - Replace `build_lib.yml` with `build_lib_cached.yml`
   - Replace `verify_consensus.yml` with `verify_consensus_cached.yml`
   - Test with a release set

4. **Update Individual Repos**
   - Update per-repo CI workflows to use cached versions
   - Ensure all use self-hosted runners

## Troubleshooting

### Cache Not Working
- Check `/tmp/runner-cache` exists and is writable
- Verify rsync is installed
- Check disk space
- Review cache key generation

### Disk Space Issues
- Increase cleanup frequency
- Reduce cache retention count
- Move cache to larger disk
- Add disk space monitoring

### Performance Not Improved
- Check cache hit rates
- Verify cache is being used
- Check for cache corruption
- Review cache key strategy

## See Also

- `WORKFLOW_PATTERNS_ANALYSIS.md` - Detailed pattern analysis
- `WORKFLOW_METHODOLOGY.md` - Current workflow methodology
- `scripts/README.md` - Monitoring and management scripts

