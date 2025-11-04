#!/bin/bash
#
# Setup Local Cache System for BTCDecoded Runners
# Configures cache directories for faster builds
#
# Usage: sudo ./setup-cache.sh [cache-dir]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CACHE_DIR="${1:-/tmp/runner-cache}"
RUNNER_USER="${SUDO_USER:-$(whoami)}"

echo -e "${BLUE}📦 Setting up BTCDecoded Runner Cache System${NC}"
echo "====================================="
echo ""

# Create cache directory structure
echo -e "${BLUE}Creating cache directories...${NC}"
mkdir -p "$CACHE_DIR"/{deps,builds,cargo-registry,cargo-git,cargo-build}

# Set permissions
chown -R "$RUNNER_USER:$RUNNER_USER" "$CACHE_DIR"
chmod -R 755 "$CACHE_DIR"

echo -e "${GREEN}✅ Cache directory structure created${NC}"
echo ""
echo "Cache directories:"
echo "  📦 $CACHE_DIR/deps/          - Dependency caches"
echo "  📦 $CACHE_DIR/builds/        - Build artifacts"
echo "  📦 $CACHE_DIR/cargo-registry/ - Cargo registry cache"
echo "  📦 $CACHE_DIR/cargo-git/     - Cargo git cache"
echo "  📦 $CACHE_DIR/cargo-build/   - Cargo build cache"
echo ""

# Setup Cargo environment
echo -e "${BLUE}Configuring Cargo cache...${NC}"
if [ -d "$HOME/.cargo" ]; then
    # Create or update Cargo config
    CARGO_CONFIG="$HOME/.cargo/config.toml"
    mkdir -p "$HOME/.cargo"
    
    if [ ! -f "$CARGO_CONFIG" ]; then
        cat > "$CARGO_CONFIG" << EOF
[build]
incremental = true

[net]
git-fetch-with-cli = true
EOF
        echo -e "${GREEN}✅ Created Cargo config${NC}"
    fi
    
    # Set environment variables
    echo ""
    echo -e "${YELLOW}Add these to your environment:${NC}"
    echo "export CARGO_HOME=\"$CACHE_DIR/cargo-registry\""
    echo "export CARGO_TARGET_DIR=\"$CACHE_DIR/cargo-build\""
    echo ""
else
    echo -e "${YELLOW}⚠️  Cargo not found, skipping Cargo config${NC}"
fi

# Setup cleanup script
CLEANUP_SCRIPT="$CACHE_DIR/cleanup.sh"
cat > "$CLEANUP_SCRIPT" << 'EOF'
#!/bin/bash
# Cleanup old cache entries
# Usage: ./cleanup.sh [days-to-keep]

DAYS_TO_KEEP="${1:-7}"
CACHE_DIR="$(dirname "$0")"

echo "🧹 Cleaning cache older than ${DAYS_TO_KEEP} days..."

# Clean old dependency caches
find "$CACHE_DIR/deps" -maxdepth 1 -type d -mtime +$DAYS_TO_KEEP -exec rm -rf {} + 2>/dev/null || true

# Clean old build artifacts
find "$CACHE_DIR/builds" -maxdepth 1 -type d -mtime +$DAYS_TO_KEEP -exec rm -rf {} + 2>/dev/null || true

echo "✅ Cleanup complete"
EOF

chmod +x "$CLEANUP_SCRIPT"
chown "$RUNNER_USER:$RUNNER_USER" "$CLEANUP_SCRIPT"

echo -e "${GREEN}✅ Cleanup script created: ${CLEANUP_SCRIPT}${NC}"
echo ""

# Summary
echo "====================================="
echo -e "${GREEN}✅ Cache setup complete${NC}"
echo ""
echo "Cache location: $CACHE_DIR"
echo "Owner: $RUNNER_USER"
echo ""
echo "Next steps:"
echo "  1. Set environment variables for Cargo cache"
echo "  2. Configure workflows to use cache directories"
echo "  3. Set up periodic cleanup (cron or systemd timer)"
echo ""
echo "Cleanup old cache:"
echo "  $CLEANUP_SCRIPT [days-to-keep]"

