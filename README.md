# BLLVM - Bitcoin Low-Level Virtual Machine Node

**Main binary for Bitcoin Commons BLLVM node implementation.**

This is the standalone binary crate that provides the `bllvm` executable. It depends on the `bllvm-node` library and provides a command-line interface for running a full Bitcoin node.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Configuration Hierarchy](#configuration-hierarchy)
  - [CLI Arguments](#cli-arguments)
  - [Environment Variables](#environment-variables)
  - [Config File](#config-file)
- [Operation](#operation)
  - [Running the Node](#running-the-node)
  - [Monitoring](#monitoring)
  - [Network Modes](#network-modes)
- [Verification](#verification)
  - [Binary Verification](#binary-verification)
  - [Checksum Verification](#checksum-verification)
  - [Verification Bundles](#verification-bundles)
- [Advanced Topics](#advanced-topics)
  - [Feature Flags](#feature-flags)
  - [Module System](#module-system)
  - [Network Configuration](#network-configuration)
  - [Resource Limits](#resource-limits)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [Building from Source](#building-from-source)
- [License](#license)

---

## Installation

### From Source

```bash
git clone https://github.com/BTCDecoded/bllvm.git
cd bllvm
cargo build --release
```

The binary will be at `target/release/bllvm`.

### From Packages

- **Debian/Ubuntu**: `.deb` package (coming soon)
- **Arch Linux**: AUR package (coming soon)
- **Windows**: `.exe` installer (coming soon)

---

## Quick Start

```bash
# Start node in regtest mode (default, safe for development)
bllvm

# Start node on testnet
bllvm --network testnet

# Start node on mainnet (use with caution)
bllvm --network mainnet

# Custom data directory
bllvm --data-dir /var/lib/bllvm

# Verbose logging
bllvm --verbose
```

## Commands

The `bllvm` binary supports subcommands for node management and information queries. If no subcommand is provided, the node starts (default behavior).

### Node Information Commands

```bash
# Show comprehensive node status
bllvm status

# Health check (exit code 0 if healthy)
bllvm health

# Show version and build information
bllvm version

# Show blockchain information
bllvm chain

# Show connected peers
bllvm peers

# Show network information
bllvm network

# Show sync status
bllvm sync
```

### Configuration Commands

```bash
# Show loaded configuration
bllvm config show

# Validate configuration file
bllvm config validate [path]

# Show configuration file path
bllvm config path
```

### RPC Commands

```bash
# Direct RPC call
bllvm rpc <method> [params]

# Example: Get blockchain info
bllvm rpc getblockchaininfo

# Example: Get peer info with custom RPC address
bllvm rpc getpeerinfo --rpc-addr 127.0.0.1:8332
```

### Command Options

All information commands support `--rpc-addr` to override the RPC server address:

```bash
bllvm status --rpc-addr 127.0.0.1:8332
bllvm health --rpc-addr 127.0.0.1:8332
```

---

## Configuration

BLLVM supports multiple configuration methods with a clear hierarchy. Configuration is applied in this order (highest to lowest priority):

1. **CLI Arguments** - Always wins
2. **Environment Variables** - Override config file
3. **Config File** - Main configuration source
4. **Defaults** - Built-in defaults

### Configuration Hierarchy

```bash
# Example: CLI overrides everything
# Config file: network = "testnet"
# ENV: BLLVM_NETWORK="mainnet"
# CLI: --network regtest
# Result: network = regtest (CLI wins)

bllvm --config bllvm.toml --network regtest
```

### CLI Arguments

#### Basic Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--network` | `-n` | Network to connect to (regtest/testnet/mainnet) | `regtest` |
| `--rpc-addr` | `-r` | RPC server address | `127.0.0.1:18332` |
| `--listen-addr` | `-l` | P2P listen address | `0.0.0.0:8333` |
| `--data-dir` | `-d` | Data directory | `./data` |
| `--config` | `-c` | Config file path (TOML or JSON) | Auto-detected |
| `--verbose` | `-v` | Enable verbose logging | `false` |

#### Feature Flags

| Option | Description |
|--------|-------------|
| `--enable-stratum-v2` | Enable Stratum V2 mining (requires compile-time feature) |
| `--disable-stratum-v2` | Disable Stratum V2 mining |
| `--enable-bip158` | Enable BIP158 block filtering (requires compile-time feature) |
| `--disable-bip158` | Disable BIP158 block filtering |
| `--enable-dandelion` | Enable Dandelion++ privacy relay (requires compile-time feature) |
| `--disable-dandelion` | Disable Dandelion++ privacy relay |
| `--enable-sigop` | Enable signature operations counting (requires compile-time feature) |
| `--disable-sigop` | Disable signature operations counting |

#### Advanced Options

| Option | Description | Default |
|--------|-------------|---------|
| `--target-peer-count` | Target number of peers to connect to | `8` |
| `--async-request-timeout` | Async request timeout in seconds | `300` |
| `--module-max-cpu-percent` | Module max CPU usage percentage | `50` |
| `--module-max-memory-bytes` | Module max memory in bytes | `536870912` (512MB) |

**Examples:**

```bash
# Basic usage with CLI
bllvm --network mainnet --data-dir /var/lib/bllvm

# With feature flags
bllvm --enable-stratum-v2 --enable-dandelion

# With advanced options
bllvm --target-peer-count 16 --async-request-timeout 600

# Combined
bllvm --network testnet \
      --data-dir ./testnet-data \
      --enable-bip158 \
      --target-peer-count 12 \
      --verbose
```

### Environment Variables

Environment variables are ideal for deployment scenarios, especially in containers and systemd services.

#### Deployment-Critical Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `BLLVM_DATA_DIR` | Data directory | `/var/lib/bllvm` |
| `BLLVM_NETWORK` | Network (regtest/testnet/mainnet) | `mainnet` |
| `BLLVM_LISTEN_ADDR` | P2P listen address | `0.0.0.0:8333` |
| `BLLVM_RPC_ADDR` | RPC server address | `127.0.0.1:8332` |
| `BLLVM_LOG_LEVEL` | Logging level (trace/debug/info/warn/error) | `info` |

#### Node Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `BLLVM_NODE_MAX_PEERS` | Maximum peer connections | `200` |
| `BLLVM_NODE_TRANSPORT` | Transport preference (tcp_only/iroh_only/hybrid) | `tcp_only` |

#### Feature Flags

| Variable | Description | Values |
|----------|-------------|--------|
| `BLLVM_NODE_FEATURES_STRATUM_V2` | Enable/disable Stratum V2 | `true`/`false` |
| `BLLVM_NODE_FEATURES_DANDELION` | Enable/disable Dandelion++ | `true`/`false` |
| `BLLVM_NODE_FEATURES_BIP158` | Enable/disable BIP158 | `true`/`false` |
| `BLLVM_NODE_FEATURES_SIGOP` | Enable/disable Sigop counting | `true`/`false` |

#### Network Timing

| Variable | Description | Default |
|----------|-------------|---------|
| `BLLVM_NETWORK_TARGET_PEER_COUNT` | Target number of peers | `8` |
| `BLLVM_NETWORK_PEER_CONNECTION_DELAY` | Peer connection delay (seconds) | `2` |
| `BLLVM_NETWORK_MAX_ADDRESSES_FROM_DNS` | Max addresses from DNS seeds | `100` |

#### Request Timeouts

| Variable | Description | Default |
|----------|-------------|---------|
| `BLLVM_REQUEST_ASYNC_TIMEOUT` | Async request timeout (seconds) | `300` |
| `BLLVM_REQUEST_UTXO_COMMITMENT_TIMEOUT` | UTXO commitment timeout (seconds) | `30` |
| `BLLVM_REQUEST_CLEANUP_INTERVAL` | Request cleanup interval (seconds) | `60` |
| `BLLVM_REQUEST_PENDING_MAX_AGE` | Max age for pending requests (seconds) | `300` |

#### Module Resource Limits

| Variable | Description | Default |
|----------|-------------|---------|
| `BLLVM_MODULE_MAX_CPU_PERCENT` | Module max CPU usage (%) | `50` |
| `BLLVM_MODULE_MAX_MEMORY_BYTES` | Module max memory (bytes) | `536870912` |
| `BLLVM_MODULE_MAX_FILE_DESCRIPTORS` | Module max file descriptors | `256` |
| `BLLVM_MODULE_MAX_CHILD_PROCESSES` | Module max child processes | `10` |
| `BLLVM_MODULE_STARTUP_WAIT_MILLIS` | Module startup wait (ms) | `100` |
| `BLLVM_MODULE_SOCKET_TIMEOUT` | Module socket timeout (seconds) | `5` |
| `BLLVM_MODULE_SOCKET_CHECK_INTERVAL` | Socket check interval (ms) | `100` |
| `BLLVM_MODULE_SOCKET_MAX_ATTEMPTS` | Max socket check attempts | `50` |

**Examples:**

```bash
# Docker/Container deployment
export BLLVM_NETWORK=mainnet
export BLLVM_DATA_DIR=/data
export BLLVM_LISTEN_ADDR=0.0.0.0:8333
export BLLVM_RPC_ADDR=0.0.0.0:8332
export BLLVM_NODE_MAX_PEERS=200
export BLLVM_LOG_LEVEL=info
bllvm

# Systemd service (see systemd example below)
```

### Config File

Config files support complex nested configurations. Config files are searched in this order:

1. `--config` flag path (if specified)
2. `./bllvm.toml` (current directory)
3. `~/.config/bllvm/bllvm.toml` (user config)
4. `/etc/bllvm/bllvm.toml` (system config)

**Example config file (`bllvm.toml`):**

```toml
# Network listening address
listen_addr = "0.0.0.0:8333"

# Transport preference: "tcp_only", "iroh_only", "hybrid"
transport_preference = "tcp_only"

# Maximum number of peers
max_peers = 100

# Protocol version: "BitcoinV1", "Testnet3", or "Regtest"
protocol_version = "Regtest"

# Enable self-advertisement (send own address to peers)
enable_self_advertisement = true

# Persistent peers (peers to connect to on startup)
# persistent_peers = ["1.2.3.4:8333", "5.6.7.8:8333"]

# Network timing configuration
[network_timing]
target_peer_count = 8
peer_connection_delay_seconds = 2
addr_relay_min_interval_seconds = 8640
max_addresses_per_addr_message = 1000
max_addresses_from_dns = 100

# Request timeout configuration
[request_timeouts]
async_request_timeout_seconds = 300
utxo_commitment_request_timeout_seconds = 30
request_cleanup_interval_seconds = 60
pending_request_max_age_seconds = 300

# Module resource limits
[module_resource_limits]
default_max_cpu_percent = 50
default_max_memory_bytes = 536870912  # 512 MB
default_max_file_descriptors = 256
default_max_child_processes = 10
module_startup_wait_millis = 100
module_socket_timeout_seconds = 5
module_socket_check_interval_millis = 100
module_socket_max_attempts = 50

# DoS protection configuration
[dos_protection]
max_connections_per_window = 10
window_seconds = 60
max_message_queue_size = 1000
max_active_connections = 1000
auto_ban_threshold = 5
ban_duration_seconds = 3600

# Relay configuration
[relay]
relay_non_standard = false
min_relay_fee = 1000  # satoshis per kB

# Address database configuration
[address_database]
max_addresses = 10000
expiration_seconds = 604800  # 7 days

# Peer rate limiting
[peer_rate_limiting]
enabled = true
messages_per_second = 10
burst_size = 20

# Stratum V2 mining configuration (requires compile-time feature)
# [stratum_v2]
# enabled = false
# pool_url = "tcp://pool.example.com:3333"
# listen_addr = "0.0.0.0:3333"
# transport_preference = "tcp_only"
# merge_mining_enabled = false
# secondary_chains = []

# RPC authentication configuration
# [rpc_auth]
# required = false
# tokens = []
# certificates = []
# rate_limit_burst = 100
# rate_limit_rate = 10

# Ban list sharing configuration
# [ban_list_sharing]
# enabled = false
# share_interval_seconds = 3600
# max_entries = 1000

# Storage and pruning configuration
# [storage]
# backend = "redb"  # "sled" or "redb"
# 
# [storage.pruning]
# enabled = false
# mode = "normal"  # "normal" or "aggressive"
# min_blocks_to_keep = 288  # ~2 days at 10 min/block
# auto_prune = false
# auto_prune_interval = 3600

# Module system configuration
# [modules]
# enabled = true
# modules_dir = "modules"
# data_dir = "data/modules"
# socket_dir = "data/modules/sockets"
# enabled_modules = []
```

See `bllvm.toml.example` for a complete example configuration file.

**Note:** Config files support both TOML and JSON formats (auto-detected by file extension).

---

## Operation

### Running the Node

#### Basic Operation

```bash
# Start node (regtest mode, default)
bllvm

# Start on testnet
bllvm --network testnet

# Start on mainnet
bllvm --network mainnet --data-dir /var/lib/bllvm
```

#### With Configuration File

```bash
# Use config file
bllvm --config /etc/bllvm/bllvm.toml

# Override config file with CLI
bllvm --config /etc/bllvm/bllvm.toml --network testnet
```

#### With Environment Variables

```bash
# Set environment variables
export BLLVM_NETWORK=mainnet
export BLLVM_DATA_DIR=/var/lib/bllvm
export BLLVM_LOG_LEVEL=info

# Run node
bllvm
```

### Monitoring

The node logs to stdout/stderr. Use `--verbose` for detailed logging:

```bash
# Verbose logging
bllvm --verbose

# Or set log level via environment
export BLLVM_LOG_LEVEL=debug
bllvm
```

Log levels (from most to least verbose):
- `trace` - Very detailed debugging
- `debug` - Debugging information
- `info` - General information (default)
- `warn` - Warning messages
- `error` - Error messages only

### Network Modes

#### Regtest (Default)

Regtest mode is safe for development and testing. It creates a local blockchain that you control.

```bash
bllvm --network regtest
```

#### Testnet

Testnet is a public test network with test coins.

```bash
bllvm --network testnet
```

#### Mainnet

Mainnet is the production Bitcoin network. Use with caution.

```bash
bllvm --network mainnet --data-dir /var/lib/bllvm
```

---

## Verification

### Binary Verification

Before running the node, you should verify the binary integrity and authenticity.

#### 1. Download Release Artifacts

Download the following files from the release page:
- `bllvm` (binary)
- `SHA256SUMS` (checksums file)
- `SHA256SUMS.asc` (signature file, if available)

#### 2. Verify Checksums

```bash
# Verify binary matches checksum
sha256sum -c SHA256SUMS

# Or manually verify
sha256sum bllvm
# Compare output with SHA256SUMS file
```

#### 3. Verify Signatures (if available)

```bash
# Import maintainer public keys (one-time setup)
gpg --import maintainer-keys.asc

# Verify signature
gpg --verify SHA256SUMS.asc SHA256SUMS
```

### Checksum Verification

All releases include `SHA256SUMS` files for verification:

```bash
# Verify all files
sha256sum -c SHA256SUMS

# Expected output:
# bllvm: OK
# bllvm-node: OK
# ...
```

### Verification Bundles

For consensus-critical releases, verification bundles are available that include:
- Kani proof results (formal verification)
- Test results
- Source code hash
- Build configuration hash
- Orange Paper specification hash

**Verification Bundle Contents:**
- `verification-artifacts.tar.gz` - Complete verification bundle
- `verification-artifacts.tar.gz.sha256` - Bundle checksum
- `verification-artifacts.tar.gz.ots` - OpenTimestamps proof (if available)

**Verify Bundle:**

```bash
# Verify bundle checksum
sha256sum -c verification-artifacts.tar.gz.sha256

# Extract and inspect
tar -xzf verification-artifacts.tar.gz
cat verify-artifacts/kani.log
cat verify-artifacts/tests.log
```

**OpenTimestamps Verification (if available):**

```bash
# Install OpenTimestamps client
pip install opentimestamps-client

# Verify timestamp
ots verify verification-artifacts.tar.gz.ots
```

---

## Advanced Topics

### Feature Flags

Some features require compile-time flags. Runtime flags will warn if a feature isn't compiled in.

**Compile-time features:**
- `stratum-v2` - Stratum V2 mining support
- `bip158` - BIP158 compact block filters
- `dandelion` - Dandelion++ privacy relay
- `sigop` - Signature operations counting
- `iroh` - Iroh transport support

**Build with features:**

```bash
cargo build --release --features stratum-v2,bip158,dandelion
```

**Runtime enable/disable:**

```bash
# Enable via CLI
bllvm --enable-stratum-v2 --enable-bip158

# Enable via ENV
export BLLVM_NODE_FEATURES_STRATUM_V2=true
export BLLVM_NODE_FEATURES_BIP158=true
bllvm

# Enable via config file
# See config file example above
```

### Module System

The module system allows extending node functionality with external modules.

**Configuration:**

```toml
[modules]
enabled = true
modules_dir = "modules"
data_dir = "data/modules"
socket_dir = "data/modules/sockets"
enabled_modules = []  # Empty = auto-discover all
```

**Resource Limits:**

```toml
[module_resource_limits]
default_max_cpu_percent = 50
default_max_memory_bytes = 536870912  # 512 MB
default_max_file_descriptors = 256
default_max_child_processes = 10
```

### Network Configuration

#### Peer Connection Settings

```toml
[network_timing]
target_peer_count = 8  # Target number of peers
peer_connection_delay_seconds = 2  # Delay before connecting
max_addresses_from_dns = 100  # Max addresses from DNS seeds
```

#### DoS Protection

```toml
[dos_protection]
max_connections_per_window = 10
window_seconds = 60
max_message_queue_size = 1000
max_active_connections = 1000
auto_ban_threshold = 5
ban_duration_seconds = 3600
```

#### Relay Configuration

```toml
[relay]
relay_non_standard = false
min_relay_fee = 1000  # satoshis per kB
```

### Resource Limits

Configure resource limits for modules and network operations:

```toml
# Module resource limits
[module_resource_limits]
default_max_cpu_percent = 50
default_max_memory_bytes = 536870912

# Request timeouts
[request_timeouts]
async_request_timeout_seconds = 300
utxo_commitment_request_timeout_seconds = 30
```

---

## Troubleshooting

### Common Issues

#### Node Won't Start

**Check data directory permissions:**
```bash
ls -la /var/lib/bllvm
# Ensure directory is writable
chmod 755 /var/lib/bllvm
```

**Check port availability:**
```bash
# Check if port is in use
netstat -tuln | grep 8333
# Or use different port
bllvm --listen-addr 0.0.0.0:18333
```

#### Connection Issues

**Check firewall:**
```bash
# Allow Bitcoin P2P port (8333 for mainnet, 18333 for testnet)
sudo ufw allow 8333/tcp
```

**Check network configuration:**
```bash
# Verify network mode
bllvm --network testnet --verbose
# Look for connection attempts in logs
```

#### Configuration Issues

**Verify config file syntax:**
```bash
# TOML syntax check (if toml-cli installed)
toml validate bllvm.toml
```

**Check configuration hierarchy:**
```bash
# CLI overrides ENV and config file
# Use --verbose to see which values are used
bllvm --config bllvm.toml --verbose
```

### Debugging

**Enable verbose logging:**
```bash
bllvm --verbose
# Or
export BLLVM_LOG_LEVEL=debug
bllvm
```

**Check logs:**
```bash
# Logs go to stdout/stderr
bllvm 2>&1 | tee bllvm.log
```

**Verify binary:**
```bash
# Check binary version
bllvm --version  # (if implemented)

# Verify checksums
sha256sum -c SHA256SUMS
```

---

## Architecture

This binary depends on:
- `bllvm-node`: Core node library (depends on bllvm-protocol and bllvm-consensus)

**Dependency Chain:**
```
bllvm (binary)
  └── bllvm-node (library)
       ├── bllvm-protocol (library)
       │    └── bllvm-consensus (library)
       └── bllvm-consensus (library)
```

---

## Building from Source

### Prerequisites

- Rust toolchain (see `rust-toolchain.toml` for required version)
- Cargo (comes with Rust)
- Git

### Build Steps

```bash
# Clone repository
git clone https://github.com/BTCDecoded/bllvm.git
cd bllvm

# Build release binary
cargo build --release

# Binary will be at target/release/bllvm
```

### Build with Features

```bash
# Build with all features
cargo build --release --all-features

# Build with specific features
cargo build --release --features stratum-v2,bip158
```

### Deterministic Builds

For reproducible builds:

```bash
# Use locked dependencies
cargo build --release --locked

# Verify build
sha256sum target/release/bllvm
# Compare with release SHA256SUMS
```

---

## Deployment Examples

### Docker/Container

```bash
# Use environment variables
docker run -e BLLVM_NETWORK=mainnet \
           -e BLLVM_DATA_DIR=/data \
           -e BLLVM_LISTEN_ADDR=0.0.0.0:8333 \
           -e BLLVM_RPC_ADDR=0.0.0.0:8332 \
           -e BLLVM_NODE_MAX_PEERS=200 \
           -v /path/to/data:/data \
           -p 8333:8333 \
           -p 8332:8332 \
           bllvm:latest
```

### Systemd Service

Create `/etc/systemd/system/bllvm.service`:

```ini
[Unit]
Description=BLLVM Bitcoin Node
After=network.target

[Service]
Type=simple
User=bllvm
Group=bllvm
Environment="BLLVM_NETWORK=mainnet"
Environment="BLLVM_DATA_DIR=/var/lib/bllvm"
Environment="BLLVM_LISTEN_ADDR=0.0.0.0:8333"
Environment="BLLVM_RPC_ADDR=127.0.0.1:8332"
Environment="BLLVM_LOG_LEVEL=info"
ExecStart=/usr/bin/bllvm
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable bllvm
sudo systemctl start bllvm
sudo systemctl status bllvm
```

### Development

```bash
# Use config file for development
bllvm --config ./bllvm.toml --network regtest --verbose
```

---

## License

MIT

---

## Additional Resources

- **Configuration Guide**: See `CONFIGURATION.md` for detailed configuration documentation
- **Example Config**: See `bllvm.toml.example` for a complete configuration example
- **Project Documentation**: https://github.com/BTCDecoded
- **Website**: https://btcdecoded.org
