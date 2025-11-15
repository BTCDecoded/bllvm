# BLLVM - Bitcoin Low-Level Virtual Machine Node

**Main binary for Bitcoin Commons BLLVM node implementation.**

This is the standalone binary crate that provides the `bllvm` executable. It depends on the `bllvm-node` library and provides a command-line interface for running a full Bitcoin node.

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

## Usage

```bash
# Start node in regtest mode (default, safe for development)
bllvm

# Start node on testnet
bllvm --network testnet

# Start node on mainnet (use with caution)
bllvm --network mainnet

# Custom RPC and P2P addresses
bllvm --rpc-addr 127.0.0.1:8332 --listen-addr 0.0.0.0:8333

# Custom data directory
bllvm --data-dir /path/to/data

# Verbose logging
bllvm --verbose
```

## Options

- `--network, -n`: Network to connect to (regtest, testnet, mainnet) [default: regtest]
- `--rpc-addr, -r`: RPC server address [default: 127.0.0.1:18332]
- `--listen-addr, -l`: P2P listen address [default: 0.0.0.0:8333]
- `--data-dir, -d`: Data directory [default: ./data]
- `--verbose, -v`: Enable verbose logging

## Architecture

This binary depends on:
- `bllvm-node`: Core node library (depends on bllvm-protocol and bllvm-consensus)

## Building

```bash
cargo build --release
```

## License

MIT

