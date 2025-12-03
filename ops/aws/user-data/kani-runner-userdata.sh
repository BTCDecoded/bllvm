#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

RUNNER_USER="actions-runner"
RUNNER_DIR="/opt/actions-runner"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted, Linux, X64, spot, kani}"

# Wait for metadata service
until curl -s http://169.254.169.254/latest/meta-data/instance-id; do
  sleep 1
done

# Download and install runner (if not already installed)
if [ ! -f "$RUNNER_DIR/bin/Runner.Listener" ]; then
  cd /tmp
  RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/v//')
  curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
  sudo tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -C "$RUNNER_DIR"
  sudo chown -R $RUNNER_USER:$RUNNER_USER "$RUNNER_DIR"
fi

# Configure runner (if token provided)
if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
  cd "$RUNNER_DIR"
  sudo -u $RUNNER_USER ./config.sh \
    --url "https://github.com/$GITHUB_REPO" \
    --token "$GITHUB_TOKEN" \
    --labels "$RUNNER_LABELS" \
    --replace \
    --unattended || true
fi

# Install and start service
sudo "$RUNNER_DIR/svc.sh" install "$RUNNER_USER" || true
sudo "$RUNNER_DIR/svc.sh" start || true

# Handle spot interruption
trap 'sudo "$RUNNER_DIR/svc.sh" stop; sudo "$RUNNER_DIR/svc.sh" uninstall; exit 0' SIGTERM

# Keep script running
while true; do
  sleep 60
done



