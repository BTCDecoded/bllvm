# Quick Start Guide - Local Builds

**The easiest way to build BTCDecoded locally**

## Prerequisites

1. **Rust 1.70+** installed
   ```bash
   rustc --version  # Should show 1.70 or higher
   ```

2. **All repositories cloned** in the same parent directory:
   ```
   BTCDecoded/
   ├── commons/
   ├── bllvm-consensus/
   ├── bllvm-protocol/
   ├── bllvm-node/
   ├── bllvm-sdk/
   └── governance-app/
   ```

## One-Command Build (Easiest)

```bash
cd /path/to/BTCDecoded/commons
./build-local.sh
```

**That's it!** This will:
- ✅ Check Rust toolchain
- ✅ Verify all repos exist
- ✅ Build all repos in dependency order
- ✅ Collect binaries to `artifacts/binaries/`

## Options

### Development Build (Default)
```bash
./build-local.sh --dev
```
Uses local path dependencies, perfect for development.

### Release Build
```bash
./build-local.sh --release
```
Uses git dependencies, suitable for release testing.

### Clean Build
```bash
./build-local.sh --clean
```
Cleans all repos before building.

### Combined
```bash
./build-local.sh --release --clean
```
Clean release build.

## Alternative: Full Build Script

If you need more control:

```bash
cd /path/to/BTCDecoded/commons
./build.sh --mode dev
```

## Getting Help

```bash
./build-local.sh --help
```

## Output

After a successful build, you'll find:
- **Binaries**: `commons/artifacts/binaries/`
  - `bllvm-node`
  - `bllvm-keygen`, `bllvm-sign`, `bllvm-verify`
  - `governance-app`, `key-manager`, etc.

## Troubleshooting

### Missing Repos
```bash
cd /path/to/BTCDecoded/commons
./scripts/setup-build-env.sh
```

### Build Fails
```bash
# Clean and rebuild
./build-local.sh --clean
```

### Rust Version Too Old
```bash
rustup update stable
```

## Next Steps

- See `BUILD_CHAINING_GUIDE.md` for advanced usage
- See `LOCAL_BUILD_VERIFICATION.md` for verification details
- See `BUILD_SYSTEM.md` for complete documentation

