#!/bin/bash
#
# Start BTCDecoded Self-Hosted Runner
# Helps start the GitHub Actions self-hosted runner
#
# Usage: ./start-runner.sh [runner-dir]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RUNNER_DIR="${1:-${RUNNER_DIR:-}}"

echo -e "${BLUE}🚀 BTCDecoded Self-Hosted Runner Startup${NC}"
echo "====================================="

# Check if we're in the right directory or runner dir is specified
if [ -n "$RUNNER_DIR" ]; then
    cd "$RUNNER_DIR" || exit 1
fi

if [ ! -f "run.sh" ]; then
    echo -e "${RED}❌ Error: run.sh not found in current directory${NC}"
    echo "Please navigate to your runner directory first"
    echo ""
    echo "Typical runner directory structure:"
    echo "actions-runner/"
    echo "├── run.sh"
    echo "├── config.sh"
    echo "├── svc.sh"
    echo "└── ..."
    echo ""
    echo "If you need to set up a new runner:"
    echo "1. Go to: https://github.com/BTCDecoded/commons/settings/actions/runners"
    echo "2. Click 'New self-hosted runner'"
    echo "3. Follow the setup instructions"
    exit 1
fi

# Check if runner is already running
if pgrep -f "Runner.Listener" > /dev/null; then
    echo -e "${YELLOW}⚠️  Runner appears to be already running${NC}"
    echo "Processes found:"
    pgrep -f "Runner.Listener" | xargs ps -p 2>/dev/null || true
    echo ""
    read -p "Do you want to restart the runner? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🔄 Stopping existing runner...${NC}"
        ./svc.sh stop 2>/dev/null || true
        sleep 2
    else
        echo -e "${GREEN}✅ Runner is already running, exiting${NC}"
        exit 0
    fi
fi

# Start the runner
echo -e "${BLUE}🚀 Starting self-hosted runner...${NC}"
echo "This will connect to GitHub and start processing queued workflows"
echo ""

# Check if running as service or directly
if [ -f "svc.sh" ]; then
    echo -e "${BLUE}📋 Starting as service...${NC}"
    ./svc.sh start
    echo -e "${GREEN}✅ Runner service started${NC}"
    echo ""
    echo "To check status: ./svc.sh status"
    echo "To stop: ./svc.sh stop"
    echo "To view logs: ./svc.sh status"
else
    echo -e "${BLUE}📋 Starting directly...${NC}"
    echo "Press Ctrl+C to stop the runner"
    echo ""
    ./run.sh
fi

echo ""
echo -e "${GREEN}🎉 Runner startup complete!${NC}"
echo "Check your GitHub Actions tab to see workflows start processing"

