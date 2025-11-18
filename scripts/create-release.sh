#!/bin/bash
#
# Create a unified release for BTCDecoded ecosystem
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${COMMONS_DIR}/artifacts"

VERSION_TAG="${1:-}"
if [ -z "$VERSION_TAG" ]; then
    echo "Usage: $0 <version-tag>"
    echo "Example: $0 v0.1.0"
    exit 1
fi

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

create_release_notes() {
    local notes_file="${ARTIFACTS_DIR}/RELEASE_NOTES.md"
    
    cat > "$notes_file" <<EOF
# BTCDecoded Release ${VERSION_TAG}

Release date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Components

This release includes the following components:

- **bllvm-consensus** - Direct mathematical implementation of Bitcoin consensus rules
- **bllvm-protocol** - Bitcoin protocol abstraction layer
- **bllvm-node** - Minimal Bitcoin node implementation
- **bllvm-sdk** - Governance infrastructure and CLI tools
- **bllvm-commons** - GitHub App for cryptographic governance enforcement

## Build Variants

This release includes two build variants:

### Base Variant (\`bllvm-{version}-{platform}.tar.gz\`)
**Purpose**: Stable, minimal release with core functionality only

**Features**:
- Core \`bllvm\` binary
- Production optimizations
- Standard storage backends

**Use this variant for**: Production deployments, stability priority

### Experimental Variant (\`bllvm-experimental-{version}-{platform}.tar.gz\`)
**Purpose**: Full-featured build with all experimental features

**Features**:
- All base features
- UTXO commitments
- Dandelion++ privacy relay
- BIP119 CheckTemplateVerify (CTV)
- Stratum V2 mining
- BIP158 compact block filters
- Signature operations counting

**Use this variant for**: Development, testing, advanced features

## Binaries Included

Both variants include:
- \`bllvm\` - Bitcoin reference node
- \`bllvm-keygen\` - Key generation tool
- \`bllvm-sign\` - Message signing tool
- \`bllvm-verify\` - Signature verification tool
- \`bllvm-commons\` - Governance application server
- \`key-manager\` - Key management utility
- \`test-content-hash\` - Content hash testing tool
- \`test-content-hash-standalone\` - Standalone content hash test

## Installation

### Base Variant
\`\`\`bash
tar -xzf bllvm-${VERSION_TAG}-linux-x86_64.tar.gz
sudo mv binaries/* /usr/local/bin/
\`\`\`

### Experimental Variant
\`\`\`bash
tar -xzf bllvm-experimental-${VERSION_TAG}-linux-x86_64.tar.gz
sudo mv binaries-experimental/* /usr/local/bin/
\`\`\`

## Verification

Verify checksums:

### Base Variant
\`\`\`bash
sha256sum -c SHA256SUMS-linux-x86_64
sha256sum -c SHA256SUMS-windows-x86_64
\`\`\`

### Experimental Variant
\`\`\`bash
sha256sum -c SHA256SUMS-experimental-linux-x86_64
sha256sum -c SHA256SUMS-experimental-windows-x86_64
\`\`\`

Verify component provenance:

\`\`\`bash
# Check release manifest for component versions and hashes
cat release-manifest.json | jq '.'
\`\`\`

Component manifests are available in the \`manifests/\` directory for detailed provenance information.

## Documentation

For more information, visit:
- https://github.com/BTCDecoded
- https://btcdecoded.org

## License

MIT License - see individual repository LICENSE files for details.
EOF

    log_success "Created release notes: ${notes_file}"
}

rename_archives() {
    log_info "Renaming archives to include version tag: ${VERSION_TAG}"
    
    pushd "$ARTIFACTS_DIR" > /dev/null
    
    # Rename base variant archives
    for platform in linux-x86_64 windows-x86_64; do
        # Rename tar.gz files
        if [ -f "bllvm-${platform}.tar.gz" ]; then
            mv "bllvm-${platform}.tar.gz" "bllvm-${VERSION_TAG}-${platform}.tar.gz"
            log_success "Renamed: bllvm-${platform}.tar.gz -> bllvm-${VERSION_TAG}-${platform}.tar.gz"
        fi
        
        # Rename zip files
        if [ -f "bllvm-${platform}.zip" ]; then
            mv "bllvm-${platform}.zip" "bllvm-${VERSION_TAG}-${platform}.zip"
            log_success "Renamed: bllvm-${platform}.zip -> bllvm-${VERSION_TAG}-${platform}.zip"
        fi
        
        # Rename experimental variant archives
        if [ -f "bllvm-experimental-${platform}.tar.gz" ]; then
            mv "bllvm-experimental-${platform}.tar.gz" "bllvm-experimental-${VERSION_TAG}-${platform}.tar.gz"
            log_success "Renamed: bllvm-experimental-${platform}.tar.gz -> bllvm-experimental-${VERSION_TAG}-${platform}.tar.gz"
        fi
        
        if [ -f "bllvm-experimental-${platform}.zip" ]; then
            mv "bllvm-experimental-${platform}.zip" "bllvm-experimental-${VERSION_TAG}-${platform}.zip"
            log_success "Renamed: bllvm-experimental-${platform}.zip -> bllvm-experimental-${VERSION_TAG}-${platform}.zip"
        fi
    done
    
    popd > /dev/null
}

main() {
    log_info "Creating release for tag: ${VERSION_TAG}"
    
    # Check for both base and experimental variants
    if [ ! -d "$ARTIFACTS_DIR" ] || ([ ! -d "${ARTIFACTS_DIR}/binaries" ] && [ ! -d "${ARTIFACTS_DIR}/binaries-experimental" ]); then
        log_info "Artifacts directory not found. Artifacts should be collected before creating release."
        log_info "Expected directories:"
        log_info "  - ${ARTIFACTS_DIR}/binaries (base variant)"
        log_info "  - ${ARTIFACTS_DIR}/binaries-experimental (experimental variant)"
    fi
    
    create_release_notes
    rename_archives
    
    log_success "Release created for ${VERSION_TAG}"
    log_info "Release artifacts: ${ARTIFACTS_DIR}"
    log_info "Base variant: ${ARTIFACTS_DIR}/binaries"
    log_info "Experimental variant: ${ARTIFACTS_DIR}/binaries-experimental"
}

main "$@"

