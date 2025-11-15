#!/bin/bash
#
# Create Debian package for bllvm binary
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$COMMONS_DIR")"
VERSION="${1:-0.1.0}"
ARCH="${2:-amd64}"

PACKAGE_NAME="bllvm"
PACKAGE_DIR="${COMMONS_DIR}/artifacts/${PACKAGE_NAME}-${VERSION}-${ARCH}"
DEBIAN_DIR="${PACKAGE_DIR}/DEBIAN"
BINARY_DIR="${PACKAGE_DIR}/usr/bin"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_info "Creating Debian package for ${PACKAGE_NAME} ${VERSION} (${ARCH})..."

# Create package structure
mkdir -p "${DEBIAN_DIR}"
mkdir -p "${BINARY_DIR}"

# Copy binary
if [ -f "${PARENT_DIR}/bllvm/target/release/bllvm" ]; then
    cp "${PARENT_DIR}/bllvm/target/release/bllvm" "${BINARY_DIR}/"
    chmod +x "${BINARY_DIR}/bllvm"
    log_success "Copied binary"
else
    echo "Error: Binary not found at ${PARENT_DIR}/bllvm/target/release/bllvm"
    exit 1
fi

# Create control file
cat > "${DEBIAN_DIR}/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: Bitcoin Commons Team <team@btcdecoded.org>
Description: Bitcoin Commons BLLVM - Bitcoin Low-Level Virtual Machine Node
 Bitcoin Commons BLLVM is a minimal, production-ready Bitcoin node
 implementation that uses protocol abstraction and consensus-proof for
 all consensus decisions.
Homepage: https://btcdecoded.org
EOF

# Build package
log_info "Building .deb package..."
dpkg-deb --build "${PACKAGE_DIR}" "${COMMONS_DIR}/artifacts/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

log_success "Created: ${COMMONS_DIR}/artifacts/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

