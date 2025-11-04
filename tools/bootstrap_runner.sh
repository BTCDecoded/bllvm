#!/bin/bash
# Bootstrap a self-hosted runner with required toolchains
# Usage: sudo ./bootstrap_runner.sh [--rust] [--docker] [--kani] [--ghcr USER TOKEN] [--cache-dir DIR]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_RUST=0
INSTALL_DOCKER=0
INSTALL_KANI=0
GHCR_USER=""
GHCR_TOKEN=""
CACHE_DIR="/tmp/runner-cache"
SETUP_CACHE=0

show_usage() {
    cat << EOF
Bootstrap BTCDecoded Self-Hosted Runner

Usage: sudo $0 [options]

Options:
    --rust              Install Rust toolchain (rustup)
    --docker            Install Docker engine
    --kani              Install Kani model checker
    --ghcr USER TOKEN   Login to GitHub Container Registry
    --cache-dir DIR     Setup cache directory (default: /tmp/runner-cache)
    --all               Install all tools (Rust, Docker, Kani, cache)
    -h, --help          Show this help message

Examples:
    sudo $0 --all                    # Install everything
    sudo $0 --rust --docker          # Install Rust and Docker
    sudo $0 --cache-dir /opt/cache   # Setup cache directory

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rust) INSTALL_RUST=1; shift ;;
    --docker) INSTALL_DOCKER=1; shift ;;
    --kani) INSTALL_KANI=1; shift ;;
    --ghcr) GHCR_USER="$2"; GHCR_TOKEN="$3"; shift 3 ;;
    --cache-dir) CACHE_DIR="$2"; SETUP_CACHE=1; shift 2 ;;
    --all) INSTALL_RUST=1; INSTALL_DOCKER=1; INSTALL_KANI=1; SETUP_CACHE=1; shift ;;
    -h|--help) show_usage; exit 0 ;;
    *) echo -e "${RED}Unknown arg: $1${NC}" >&2; show_usage; exit 2 ;;
  esac
done

RUNNER_USER="${SUDO_USER:-$(whoami)}"

echo -e "${BLUE}🚀 BTCDecoded Runner Bootstrap${NC}"
echo "====================================="
echo ""

# Setup cache directory
if [[ $SETUP_CACHE -eq 1 ]]; then
  echo -e "${BLUE}📦 Setting up cache directory...${NC}"
  mkdir -p "$CACHE_DIR"/{deps,builds,cargo-registry,cargo-git}
  chown -R "$RUNNER_USER:$RUNNER_USER" "$CACHE_DIR"
  echo -e "${GREEN}✅ Cache directory: ${CACHE_DIR}${NC}"
  echo ""
fi

# Install Rust
if [[ $INSTALL_RUST -eq 1 ]]; then
  echo -e "${BLUE}🦀 Installing Rust toolchain...${NC}"
  if command -v rustc >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Rust already installed: $(rustc --version)${NC}"
  else
    su - "$RUNNER_USER" -c "curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable"
    echo -e "${GREEN}✅ Rust toolchain installed${NC}"
  fi
  echo ""
fi

# Install Docker
if [[ $INSTALL_DOCKER -eq 1 ]]; then
  echo -e "${BLUE}🐳 Installing Docker...${NC}"
  if command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker already installed: $(docker --version)${NC}"
  else
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker "$RUNNER_USER"
    echo -e "${GREEN}✅ Docker installed${NC}"
    echo -e "${YELLOW}⚠️  Reboot required for docker group permissions${NC}"
  fi
  echo ""
fi

# Install Kani
if [[ $INSTALL_KANI -eq 1 ]]; then
  echo -e "${BLUE}🔍 Installing Kani model checker...${NC}"
  if command -v kani >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Kani already installed: $(kani --version)${NC}"
  else
    su - "$RUNNER_USER" -c "curl -fsSL https://model-checking.github.io/kani/install.sh | sh -s -- -y"
    echo -e "${GREEN}✅ Kani installed${NC}"
  fi
  echo ""
fi

# Login to GHCR
if [[ -n "$GHCR_USER" && -n "$GHCR_TOKEN" ]]; then
  echo -e "${BLUE}🔐 Logging in to GitHub Container Registry...${NC}"
  if command -v docker >/dev/null 2>&1; then
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
    echo -e "${GREEN}✅ Logged in to GHCR as ${GHCR_USER}${NC}"
  else
    echo -e "${RED}❌ Docker not installed, cannot login to GHCR${NC}"
  fi
  echo ""
fi

# Summary
echo "====================================="
echo -e "${GREEN}✅ Bootstrap complete${NC}"
echo ""
echo "Installed components:"
[[ $INSTALL_RUST -eq 1 ]] && echo "  ✅ Rust toolchain"
[[ $INSTALL_DOCKER -eq 1 ]] && echo "  ✅ Docker"
[[ $INSTALL_KANI -eq 1 ]] && echo "  ✅ Kani"
[[ $SETUP_CACHE -eq 1 ]] && echo "  ✅ Cache directory: ${CACHE_DIR}"
[[ -n "$GHCR_USER" ]] && echo "  ✅ GHCR login: ${GHCR_USER}"
echo ""
echo "Next steps:"
echo "  1. Configure GitHub Actions runner labels"
echo "  2. Set up runner as service (see ops/SELF_HOSTED_RUNNER.md)"
if [[ $INSTALL_DOCKER -eq 1 ]]; then
  echo "  3. Reboot to apply docker group permissions"
fi
