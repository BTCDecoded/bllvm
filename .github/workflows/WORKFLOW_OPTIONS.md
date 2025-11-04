# Workflow Options Standardization

**Date:** 2025-01-XX  
**Status:** Standardization Guide

## Standard Input Options

### Common Options Across All Workflows

#### Required Options
- `repo` - Repository name (string, required)
- `ref` - Git reference/tag (string, required)

#### Optional Options (Standard)
- `use_cache` - Enable local caching (boolean, default: true)
- `timeout_minutes` - Job timeout (number, default: varies by job type)
- `verify_deterministic` - Verify deterministic builds (boolean, default: false)

#### Build-Specific Options
- `package` - Cargo package name (string, default: "")
- `features` - Cargo features (string, default: "")
- `release` - Build in release mode (boolean, default: true)

#### Verification-Specific Options
- `kani` - Run Kani verification (boolean, default: true)

#### Docker-Specific Options
- `context` - Docker build context (string, default: ".")
- `image_name` - Docker image name (string, default: "governance-app")
- `push` - Push to registry (boolean, default: false)
- `tag` - Docker image tag (string, required for docker)

## Workflow Input Matrix

| Workflow | repo | ref | package | features | release | verify_deterministic | use_cache | kani | context | image_name | push | tag |
|----------|------|-----|---------|----------|--------|---------------------|-----------|------|---------|------------|------|-----|
| build_lib.yml | ✅ req | ✅ req | ✅ opt | ✅ opt | ✅ opt | ✅ opt | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| build_lib_cached.yml | ✅ req | ✅ req | ✅ opt | ✅ opt | ✅ opt | ✅ opt | ✅ opt | ❌ | ❌ | ❌ | ❌ | ❌ |
| verify_consensus.yml | ✅ opt | ✅ req | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ opt | ❌ | ❌ | ❌ | ❌ |
| verify_consensus_cached.yml | ✅ opt | ✅ req | ❌ | ❌ | ❌ | ❌ | ✅ opt | ✅ opt | ❌ | ❌ | ❌ | ❌ |
| build_docker.yml | ✅ req | ✅ req | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ opt | ✅ opt | ✅ opt | ✅ req |

## Standardization Rules

### 1. All workflows should have:
- `timeout-minutes` at job level
- `permissions` block (even if minimal)
- `env` block for consistent environment
- Consistent option naming

### 2. Cached workflows should:
- Have `use_cache` option (default: true)
- Handle cache restoration conditionally
- Always cleanup cache at end

### 3. Build workflows should:
- Support `package`, `features`, `release` options
- Support `verify_deterministic` option
- Generate SHA256SUMS consistently

### 4. Verification workflows should:
- Support `kani` option
- Support `use_cache` option (if cached version)
- Upload logs consistently

### 5. Docker workflows should:
- Support `context`, `image_name`, `push`, `tag` options
- Handle registry login conditionally
- Support multi-platform builds

## Missing Options

### build_lib.yml
- ❌ Missing: `use_cache` option (should add or create cached version)
- ❌ Missing: `timeout-minutes` at job level
- ❌ Missing: `permissions` block
- ❌ Missing: `env` block

### verify_consensus.yml
- ❌ Missing: `use_cache` option
- ❌ Missing: `timeout-minutes` at job level
- ❌ Missing: `permissions` block
- ❌ Missing: `env` block

### build_docker.yml
- ❌ Missing: `use_cache` option (for source caching)
- ❌ Missing: `timeout-minutes` at job level
- ❌ Missing: `permissions` block
- ❌ Missing: `env` block

### release_orchestrator.yml
- ❌ Not passing: `verify_deterministic` option
- ❌ Not passing: `use_cache` option
- ❌ Not passing: `features` option (where applicable)

## Recommended Updates

1. **Add standard options to all workflows**
2. **Update release_orchestrator.yml to pass all options**
3. **Add timeout-minutes consistently**
4. **Add permissions blocks consistently**
5. **Add env blocks consistently**

