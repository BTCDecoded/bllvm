#!/bin/bash
#
# Create Arch Linux package for bllvm binary
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$COMMONS_DIR")"
VERSION="${1:-0.1.0}"

PACKAGE_NAME="bllvm"
PKGBUILD_DIR="${COMMONS_DIR}/artifacts/${PACKAGE_NAME}-arch"
PKG_DIR="${PKGBUILD_DIR}/pkg"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_info "Creating Arch Linux package for ${PACKAGE_NAME} ${VERSION}..."

# Create package structure
mkdir -p "${PKGBUILD_DIR}"
mkdir -p "${PKG_DIR}/${PACKAGE_NAME}/usr/bin"

# Copy binary
if [ -f "${PARENT_DIR}/bllvm/target/release/bllvm" ]; then
    cp "${PARENT_DIR}/bllvm/target/release/bllvm" "${PKG_DIR}/${PACKAGE_NAME}/usr/bin/"
    chmod +x "${PKG_DIR}/${PACKAGE_NAME}/usr/bin/bllvm"
    log_success "Copied binary"
else
    echo "Error: Binary not found at ${PARENT_DIR}/bllvm/target/release/bllvm"
    exit 1
fi

# Create PKGBUILD
cat > "${PKGBUILD_DIR}/PKGBUILD" <<EOF
# Maintainer: Bitcoin Commons Team <team@btcdecoded.org>
pkgname=${PACKAGE_NAME}
pkgver=${VERSION}
pkgrel=1
pkgdesc="Bitcoin Commons BLLVM - Bitcoin Low-Level Virtual Machine Node"
arch=('x86_64')
url="https://btcdecoded.org"
license=('MIT')
source=("bllvm")
sha256sums=('SKIP')

package() {
    install -Dm755 "\${srcdir}/bllvm" "\${pkgdir}/usr/bin/bllvm"
}
EOF

# Create .tar.xz package
log_info "Building .pkg.tar.xz package..."
cd "${PKGBUILD_DIR}"
tar -czf "${COMMONS_DIR}/artifacts/${PACKAGE_NAME}-${VERSION}-x86_64.pkg.tar.xz" -C "${PKG_DIR}/${PACKAGE_NAME}" .

log_success "Created: ${COMMONS_DIR}/artifacts/${PACKAGE_NAME}-${VERSION}-x86_64.pkg.tar.xz"

