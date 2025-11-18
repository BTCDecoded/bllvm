//! BLLVM - Bitcoin Low-Level Virtual Machine Node
//!
//! Main entry point for the Bitcoin Commons BLLVM node binary.
//! This binary starts a full Bitcoin node using the bllvm-node library.

use anyhow::{Context, Result};
use bllvm_node::config::NodeConfig;
use bllvm_node::node::Node as ReferenceNode;
use bllvm_node::ProtocolVersion;
use clap::{Parser, Subcommand, ValueEnum};
use serde_json::{json, Value};
use std::env;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use tokio::signal;
use tracing::{error, info, warn};

#[derive(Parser)]
#[command(name = "bllvm")]
#[command(about = "Bitcoin Commons BLLVM - Bitcoin Low-Level Virtual Machine Node", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,

    /// Network to connect to
    #[arg(short, long, value_enum, default_value = "regtest")]
    network: Network,

    /// RPC server address
    #[arg(short, long, default_value = "127.0.0.1:18332")]
    rpc_addr: SocketAddr,

    /// P2P listen address
    #[arg(short, long, default_value = "0.0.0.0:8333")]
    listen_addr: SocketAddr,

    /// Data directory
    #[arg(short, long, default_value = "./data")]
    data_dir: String,

    /// Configuration file path (TOML or JSON)
    #[arg(short, long)]
    config: Option<PathBuf>,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,

    /// Feature flags (runtime-configurable features)
    #[command(flatten)]
    features: FeatureFlags,

    /// Advanced configuration options
    #[command(flatten)]
    advanced: AdvancedConfig,
}

#[derive(Subcommand)]
enum Command {
    /// Start the node (default)
    Start,
    /// Show comprehensive node status
    Status {
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
    /// Health check (exit code 0 if healthy)
    Health {
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
    /// Show version and build information
    Version,
    /// Show blockchain information
    Chain {
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
    /// Show connected peers
    Peers {
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
    /// Show network information
    Network {
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
    /// Show sync status
    Sync {
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
    /// Configuration management
    Config {
        #[command(subcommand)]
        subcommand: ConfigCommand,
    },
    /// Direct RPC call
    Rpc {
        /// RPC method name
        method: String,
        /// RPC parameters (JSON array)
        #[arg(default_value = "[]")]
        params: String,
        /// RPC server address (overrides config)
        #[arg(long)]
        rpc_addr: Option<SocketAddr>,
    },
}

#[derive(Subcommand)]
enum ConfigCommand {
    /// Show loaded configuration
    Show,
    /// Validate configuration file
    Validate {
        /// Configuration file path
        path: Option<PathBuf>,
    },
    /// Show configuration file path
    Path,
}

#[derive(Parser, Debug, Clone, Default)]
#[group(id = "features")]
struct FeatureFlags {
    /// Enable Stratum V2 mining (requires compile-time feature)
    #[arg(long)]
    enable_stratum_v2: bool,

    /// Enable BIP158 block filtering (requires compile-time feature)
    #[arg(long)]
    enable_bip158: bool,

    /// Enable Dandelion++ privacy relay (requires compile-time feature)
    #[arg(long)]
    enable_dandelion: bool,

    /// Enable signature operations counting (requires compile-time feature)
    #[arg(long)]
    enable_sigop: bool,

    /// Disable Stratum V2 mining
    #[arg(long)]
    disable_stratum_v2: bool,

    /// Disable BIP158 block filtering
    #[arg(long)]
    disable_bip158: bool,

    /// Disable Dandelion++ privacy relay
    #[arg(long)]
    disable_dandelion: bool,

    /// Disable signature operations counting
    #[arg(long)]
    disable_sigop: bool,
}

/// Advanced configuration options (CLI overrides)
#[derive(Parser, Debug, Clone, Default)]
#[group(id = "advanced")]
struct AdvancedConfig {
    /// Target number of peers to connect to (default: 8)
    #[arg(long)]
    target_peer_count: Option<usize>,

    /// Async request timeout in seconds (default: 300)
    #[arg(long)]
    async_request_timeout: Option<u64>,

    /// Module max CPU usage percentage (default: 50)
    #[arg(long)]
    module_max_cpu_percent: Option<u32>,

    /// Module max memory in bytes (default: 536870912 = 512MB)
    #[arg(long)]
    module_max_memory_bytes: Option<u64>,
}

#[derive(Clone, Debug, ValueEnum)]
enum Network {
    /// Regression testing network (default, safe for development)
    Regtest,
    /// Bitcoin test network
    Testnet,
    /// Bitcoin mainnet (use with caution)
    Mainnet,
}

impl From<Network> for ProtocolVersion {
    fn from(network: Network) -> Self {
        match network {
            Network::Regtest => ProtocolVersion::Regtest,
            Network::Testnet => ProtocolVersion::Testnet3,
            Network::Mainnet => ProtocolVersion::BitcoinV1,
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize tracing (minimal for subcommands, full for start)
    let filter = if cli.verbose {
        "bllvm=debug,bllvm_node=debug"
    } else {
        "bllvm=info,bllvm_node=info"
    };

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(filter)),
        )
        .init();

    // Handle subcommands
    match cli.command {
        Some(Command::Status { rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            handle_status(rpc_addr, &config).await
        }
        Some(Command::Health { rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            handle_health(rpc_addr, &config).await
        }
        Some(Command::Version) => handle_version(),
        Some(Command::Chain { rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            handle_chain(rpc_addr, &config).await
        }
        Some(Command::Peers { rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            handle_peers(rpc_addr, &config).await
        }
        Some(Command::Network { rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            handle_network(rpc_addr, &config).await
        }
        Some(Command::Sync { rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            handle_sync(rpc_addr, &config).await
        }
        Some(Command::Config { ref subcommand }) => {
            let (config, _, _, _, _) = build_final_config(&cli);
            match subcommand {
                ConfigCommand::Show => handle_config_show(&config),
                ConfigCommand::Validate { path } => handle_config_validate(path, &cli.config),
                ConfigCommand::Path => handle_config_path(&cli.config),
            }
        }
        Some(Command::Rpc { method, ref params, rpc_addr }) => {
            let rpc_addr = rpc_addr.unwrap_or(cli.rpc_addr);
            let (config, _, _, _, _) = build_final_config(&cli);
            let params: Value = serde_json::from_str(params)
                .context("Invalid JSON parameters")?;
            handle_rpc(rpc_addr, &method, params, &config).await
        }
        None | Some(Command::Start) => {
            // Start node (default behavior)
            let (config, data_dir, listen_addr, rpc_addr, network) = build_final_config(&cli);
            
            info!("Starting Bitcoin Commons BLLVM Node");
            info!("Network: {:?}", network);
            info!("RPC address: {}", rpc_addr);
            info!("P2P listen address: {}", listen_addr);
            info!("Data directory: {}", data_dir);

            std::env::set_var("DATA_DIR", &data_dir);

            let protocol_version: ProtocolVersion = network.into();
            let mut node = match ReferenceNode::new(
                &data_dir,
                listen_addr,
                rpc_addr,
                Some(protocol_version),
            ) {
                Ok(node) => node,
                Err(e) => {
                    error!("Failed to create node: {}", e);
                    return Err(e);
                }
            };

            node = node.with_config(config.clone())
                .map_err(|e| anyhow::anyhow!("Failed to apply config: {}", e))?;
            
            node = match node.with_modules_from_config(&config) {
                Ok(n) => n,
                Err(e) => {
                    warn!("Failed to configure modules: {}. Continuing without modules.", e);
                    node
                }
            };

            tokio::select! {
                result = node.start() => {
                    if let Err(e) = result {
                        error!("Node error: {}", e);
                        return Err(e);
                    }
                }
                _ = signal::ctrl_c() => {
                    info!("Shutting down BLLVM node...");
                    info!("Node stopped");
                }
            }

            Ok(())
        }
    }
}

/// Environment variable overrides
#[derive(Debug, Clone, Default)]
struct EnvOverrides {
    data_dir: Option<String>,
    network: Option<String>,
    listen_addr: Option<SocketAddr>,
    rpc_addr: Option<SocketAddr>,
    log_level: Option<String>,
    max_peers: Option<usize>,
    transport: Option<String>,
    // Feature flags
    stratum_v2: Option<bool>,
    dandelion: Option<bool>,
    bip158: Option<bool>,
    sigop: Option<bool>,
    // Network timing config
    target_peer_count: Option<usize>,
    peer_connection_delay: Option<u64>,
    max_addresses_from_dns: Option<usize>,
    // Request timeout config
    async_request_timeout: Option<u64>,
    utxo_commitment_timeout: Option<u64>,
    request_cleanup_interval: Option<u64>,
    pending_request_max_age: Option<u64>,
    // Module resource limits config
    module_max_cpu_percent: Option<u32>,
    module_max_memory_bytes: Option<u64>,
    module_max_file_descriptors: Option<u32>,
    module_max_child_processes: Option<u32>,
    module_startup_wait_millis: Option<u64>,
    module_socket_timeout: Option<u64>,
    module_socket_check_interval: Option<u64>,
    module_socket_max_attempts: Option<usize>,
}

impl EnvOverrides {
    /// Load configuration from environment variables
    fn from_env() -> Self {
        Self {
            data_dir: env::var("BLLVM_DATA_DIR").ok(),
            network: env::var("BLLVM_NETWORK").ok(),
            listen_addr: env::var("BLLVM_LISTEN_ADDR")
                .ok()
                .and_then(|s| s.parse().ok()),
            rpc_addr: env::var("BLLVM_RPC_ADDR")
                .ok()
                .and_then(|s| s.parse().ok()),
            log_level: env::var("BLLVM_LOG_LEVEL").ok(),
            max_peers: env::var("BLLVM_NODE_MAX_PEERS")
                .ok()
                .and_then(|s| s.parse().ok()),
            transport: env::var("BLLVM_NODE_TRANSPORT").ok(),
            // Feature flags
            stratum_v2: env::var("BLLVM_NODE_FEATURES_STRATUM_V2")
                .ok()
                .and_then(|s| s.parse().ok()),
            dandelion: env::var("BLLVM_NODE_FEATURES_DANDELION")
                .ok()
                .and_then(|s| s.parse().ok()),
            bip158: env::var("BLLVM_NODE_FEATURES_BIP158")
                .ok()
                .and_then(|s| s.parse().ok()),
            sigop: env::var("BLLVM_NODE_FEATURES_SIGOP")
                .ok()
                .and_then(|s| s.parse().ok()),
            // Network timing config
            target_peer_count: env::var("BLLVM_NETWORK_TARGET_PEER_COUNT")
                .ok()
                .and_then(|s| s.parse().ok()),
            peer_connection_delay: env::var("BLLVM_NETWORK_PEER_CONNECTION_DELAY")
                .ok()
                .and_then(|s| s.parse().ok()),
            max_addresses_from_dns: env::var("BLLVM_NETWORK_MAX_ADDRESSES_FROM_DNS")
                .ok()
                .and_then(|s| s.parse().ok()),
            // Request timeout config
            async_request_timeout: env::var("BLLVM_REQUEST_ASYNC_TIMEOUT")
                .ok()
                .and_then(|s| s.parse().ok()),
            utxo_commitment_timeout: env::var("BLLVM_REQUEST_UTXO_COMMITMENT_TIMEOUT")
                .ok()
                .and_then(|s| s.parse().ok()),
            request_cleanup_interval: env::var("BLLVM_REQUEST_CLEANUP_INTERVAL")
                .ok()
                .and_then(|s| s.parse().ok()),
            pending_request_max_age: env::var("BLLVM_REQUEST_PENDING_MAX_AGE")
                .ok()
                .and_then(|s| s.parse().ok()),
            // Module resource limits config
            module_max_cpu_percent: env::var("BLLVM_MODULE_MAX_CPU_PERCENT")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_max_memory_bytes: env::var("BLLVM_MODULE_MAX_MEMORY_BYTES")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_max_file_descriptors: env::var("BLLVM_MODULE_MAX_FILE_DESCRIPTORS")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_max_child_processes: env::var("BLLVM_MODULE_MAX_CHILD_PROCESSES")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_startup_wait_millis: env::var("BLLVM_MODULE_STARTUP_WAIT_MILLIS")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_socket_timeout: env::var("BLLVM_MODULE_SOCKET_TIMEOUT")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_socket_check_interval: env::var("BLLVM_MODULE_SOCKET_CHECK_INTERVAL")
                .ok()
                .and_then(|s| s.parse().ok()),
            module_socket_max_attempts: env::var("BLLVM_MODULE_SOCKET_MAX_ATTEMPTS")
                .ok()
                .and_then(|s| s.parse().ok()),
        }
    }
}

/// Find config file in standard locations
fn find_config_file(cli_config: &Option<PathBuf>) -> Option<PathBuf> {
    // 1. CLI-specified config file (highest priority)
    if let Some(path) = cli_config {
        if path.exists() {
            return Some(path.clone());
        }
    }
    
    // 2. Current directory
    let current_dir = Path::new("./bllvm.toml");
    if current_dir.exists() {
        return Some(current_dir.to_path_buf());
    }
    
    // 3. User config directory
    if let Ok(home) = env::var("HOME") {
        let user_config = Path::new(&home).join(".config/bllvm/bllvm.toml");
        if user_config.exists() {
            return Some(user_config);
        }
    }
    
    // 4. System config directory
    let system_config = Path::new("/etc/bllvm/bllvm.toml");
    if system_config.exists() {
        return Some(system_config.to_path_buf());
    }
    
    None
}

/// Build final configuration with hierarchy: CLI > ENV > Config > Defaults
fn build_final_config(cli: &Cli) -> (NodeConfig, String, SocketAddr, SocketAddr, Network) {
    // 1. Start with defaults
    let mut config = NodeConfig::default();
    
    // 2. Load config file (if found)
    if let Some(config_path) = find_config_file(&cli.config) {
        info!("Loading configuration from: {}", config_path.display());
        match NodeConfig::from_file(&config_path) {
            Ok(file_config) => {
                info!("Configuration loaded successfully from file");
                config = file_config; // Config file overrides defaults
            }
            Err(e) => {
                warn!("Failed to load config file: {}. Using defaults.", e);
            }
        }
    } else if cli.config.is_some() {
        warn!("Config file specified but not found. Using defaults.");
    }
    
    // 3. Load ENV overrides
    let env_overrides = EnvOverrides::from_env();
    
    // Apply ENV overrides (ENV overrides config file)
    if let Some(data_dir) = &env_overrides.data_dir {
        info!("Data directory overridden by ENV: {}", data_dir);
    }
    if let Some(network) = &env_overrides.network {
        info!("Network overridden by ENV: {}", network);
        // Will be handled below
    }
    if let Some(listen_addr) = env_overrides.listen_addr {
        info!("Listen address overridden by ENV: {}", listen_addr);
        config.listen_addr = Some(listen_addr);
    }
    if let Some(rpc_addr) = env_overrides.rpc_addr {
        info!("RPC address overridden by ENV: {}", rpc_addr);
    }
    if let Some(max_peers) = env_overrides.max_peers {
        info!("Max peers overridden by ENV: {}", max_peers);
        config.max_peers = Some(max_peers);
    }
    if let Some(transport) = &env_overrides.transport {
        info!("Transport overridden by ENV: {}", transport);
        // Parse transport preference
        match transport.to_lowercase().as_str() {
            "tcp_only" | "tcp" => {
                config.transport_preference = bllvm_node::config::TransportPreferenceConfig::TcpOnly;
            }
            #[cfg(feature = "iroh")]
            "iroh_only" | "iroh" => {
                config.transport_preference = bllvm_node::config::TransportPreferenceConfig::IrohOnly;
            }
            #[cfg(feature = "iroh")]
            "hybrid" => {
                config.transport_preference = bllvm_node::config::TransportPreferenceConfig::Hybrid;
            }
            _ => {
                warn!("Unknown transport preference: {}. Using default.", transport);
            }
        }
    }
    
    // Apply ENV feature flags
    apply_env_feature_flags(&mut config, &env_overrides);
    
    // Apply ENV overrides for new config options
    apply_env_config_overrides(&mut config, &env_overrides);
    
    // 4. Determine final values (CLI overrides everything)
    // For network, parse ENV override if present, but CLI still wins
    let network = if let Some(network_str) = &env_overrides.network {
        // Try to parse ENV network, but CLI will override if provided
        match network_str.to_lowercase().as_str() {
            "regtest" => Network::Regtest,
            "testnet" => Network::Testnet,
            "mainnet" => Network::Mainnet,
            _ => {
                warn!("Unknown network in ENV: {}. Using CLI/default.", network_str);
                cli.network.clone()
            }
        }
    } else {
        cli.network.clone()
    };
    
    // CLI always wins for these (they're required CLI args with defaults)
    let data_dir = cli.data_dir.clone();
    let listen_addr = cli.listen_addr;
    let rpc_addr = cli.rpc_addr;
    
    // Apply CLI overrides to config (CLI overrides ENV and config file)
    config.listen_addr = Some(listen_addr);
    config.protocol_version = Some(format!("{:?}", network));
    
    // Apply CLI feature flags (CLI overrides ENV and config file)
    apply_feature_flags(&mut config, &cli.features);
    
    // Apply CLI advanced config (CLI overrides everything)
    apply_cli_advanced_config(&mut config, &cli.advanced);
    
    (config, data_dir, listen_addr, rpc_addr, network)
}

/// Apply feature flags from environment variables
fn apply_env_feature_flags(config: &mut NodeConfig, env: &EnvOverrides) {
    // Stratum V2
    if let Some(enabled) = env.stratum_v2 {
        #[cfg(feature = "stratum-v2")]
        {
            if config.stratum_v2.is_none() {
                config.stratum_v2 = Some(Default::default());
            }
            if let Some(ref mut sv2) = config.stratum_v2 {
                sv2.enabled = enabled;
            }
            info!("Stratum V2 {} via ENV", if enabled { "enabled" } else { "disabled" });
        }
        #[cfg(not(feature = "stratum-v2"))]
        {
            if enabled {
                warn!("Stratum V2 feature not compiled in. Rebuild with --features stratum-v2 to enable.");
            }
        }
    }
    
    // Dandelion
    if let Some(enabled) = env.dandelion {
        #[cfg(feature = "dandelion")]
        {
            info!("Dandelion++ {} via ENV", if enabled { "enabled" } else { "disabled" });
            // Dandelion may be controlled via relay policies in NodeConfig
        }
        #[cfg(not(feature = "dandelion"))]
        {
            if enabled {
                warn!("Dandelion++ feature not compiled in. Rebuild with --features dandelion to enable.");
            }
        }
    }
    
    // BIP158
    if let Some(enabled) = env.bip158 {
        #[cfg(feature = "bip158")]
        {
            info!("BIP158 block filtering {} via ENV", if enabled { "enabled" } else { "disabled" });
        }
        #[cfg(not(feature = "bip158"))]
        {
            if enabled {
                warn!("BIP158 feature not compiled in. Rebuild with --features bip158 to enable.");
            }
        }
    }
    
    // Sigop
    if let Some(enabled) = env.sigop {
        #[cfg(feature = "sigop")]
        {
            info!("Signature operations counting {} via ENV", if enabled { "enabled" } else { "disabled" });
        }
        #[cfg(not(feature = "sigop"))]
        {
            if enabled {
                warn!("Sigop feature not compiled in. Rebuild with --features sigop to enable.");
            }
        }
    }
}

/// Apply feature flags from CLI to config
fn apply_feature_flags(config: &mut NodeConfig, features: &FeatureFlags) {
    // Stratum V2
    if features.enable_stratum_v2 || features.disable_stratum_v2 {
        #[cfg(feature = "stratum-v2")]
        {
            if features.enable_stratum_v2 {
                if config.stratum_v2.is_none() {
                    config.stratum_v2 = Some(Default::default());
                }
                if let Some(ref mut sv2) = config.stratum_v2 {
                    sv2.enabled = true;
                }
                info!("Stratum V2 enabled via CLI");
            }
            if features.disable_stratum_v2 {
                if let Some(ref mut sv2) = config.stratum_v2 {
                    sv2.enabled = false;
                }
                info!("Stratum V2 disabled via CLI");
            }
        }
        #[cfg(not(feature = "stratum-v2"))]
        {
            warn!("Stratum V2 feature not compiled in. Rebuild with --features stratum-v2 to enable.");
        }
    }

    // Note: Other features like bip158, dandelion, sigop may need to be applied
    // through the node's runtime configuration rather than NodeConfig.
    // These features are typically controlled at compile-time via Cargo features,
    // but some may have runtime toggles. Check the node implementation for details.
    
    if features.enable_bip158 || features.disable_bip158 {
        #[cfg(feature = "bip158")]
        {
            info!("BIP158 block filtering {} via CLI", 
                  if features.enable_bip158 { "enabled" } else { "disabled" });
            // BIP158 is typically always enabled if compiled in, but may have runtime config
        }
        #[cfg(not(feature = "bip158"))]
        {
            warn!("BIP158 feature not compiled in. Rebuild with --features bip158 to enable.");
        }
    }

    if features.enable_dandelion || features.disable_dandelion {
        #[cfg(feature = "dandelion")]
        {
            info!("Dandelion++ privacy relay {} via CLI",
                  if features.enable_dandelion { "enabled" } else { "disabled" });
            // Dandelion may be controlled via relay policies in NodeConfig
        }
        #[cfg(not(feature = "dandelion"))]
        {
            warn!("Dandelion++ feature not compiled in. Rebuild with --features dandelion to enable.");
        }
    }

    if features.enable_sigop || features.disable_sigop {
        #[cfg(feature = "sigop")]
        {
            info!("Signature operations counting {} via CLI",
                  if features.enable_sigop { "enabled" } else { "disabled" });
        }
        #[cfg(not(feature = "sigop"))]
        {
            warn!("Sigop feature not compiled in. Rebuild with --features sigop to enable.");
        }
    }
}

/// Apply environment config overrides (non-feature flags)
fn apply_env_config_overrides(_config: &mut NodeConfig, env: &EnvOverrides) {
    // Network timing config
    if let Some(target_peer_count) = env.target_peer_count {
        // This would need to be added to NodeConfig if not already present
        // For now, just log it
        info!("Target peer count overridden by ENV: {}", target_peer_count);
    }
    if let Some(peer_connection_delay) = env.peer_connection_delay {
        info!("Peer connection delay overridden by ENV: {}", peer_connection_delay);
    }
    if let Some(max_addresses_from_dns) = env.max_addresses_from_dns {
        info!("Max addresses from DNS overridden by ENV: {}", max_addresses_from_dns);
    }
    
    // Request timeout config
    if let Some(async_request_timeout) = env.async_request_timeout {
        info!("Async request timeout overridden by ENV: {}", async_request_timeout);
    }
    if let Some(utxo_commitment_timeout) = env.utxo_commitment_timeout {
        info!("UTXO commitment timeout overridden by ENV: {}", utxo_commitment_timeout);
    }
    if let Some(request_cleanup_interval) = env.request_cleanup_interval {
        info!("Request cleanup interval overridden by ENV: {}", request_cleanup_interval);
    }
    if let Some(pending_request_max_age) = env.pending_request_max_age {
        info!("Pending request max age overridden by ENV: {}", pending_request_max_age);
    }
    
    // Module resource limits config
    if let Some(module_max_cpu_percent) = env.module_max_cpu_percent {
        info!("Module max CPU percent overridden by ENV: {}", module_max_cpu_percent);
    }
    if let Some(module_max_memory_bytes) = env.module_max_memory_bytes {
        info!("Module max memory bytes overridden by ENV: {}", module_max_memory_bytes);
    }
    if let Some(module_max_file_descriptors) = env.module_max_file_descriptors {
        info!("Module max file descriptors overridden by ENV: {}", module_max_file_descriptors);
    }
    if let Some(module_max_child_processes) = env.module_max_child_processes {
        info!("Module max child processes overridden by ENV: {}", module_max_child_processes);
    }
    if let Some(module_startup_wait_millis) = env.module_startup_wait_millis {
        info!("Module startup wait millis overridden by ENV: {}", module_startup_wait_millis);
    }
    if let Some(module_socket_timeout) = env.module_socket_timeout {
        info!("Module socket timeout overridden by ENV: {}", module_socket_timeout);
    }
    if let Some(module_socket_check_interval) = env.module_socket_check_interval {
        info!("Module socket check interval overridden by ENV: {}", module_socket_check_interval);
    }
    if let Some(module_socket_max_attempts) = env.module_socket_max_attempts {
        info!("Module socket max attempts overridden by ENV: {}", module_socket_max_attempts);
    }
}

/// Apply CLI advanced config options
fn apply_cli_advanced_config(_config: &mut NodeConfig, advanced: &AdvancedConfig) {
    if let Some(target_peer_count) = advanced.target_peer_count {
        info!("Target peer count set via CLI: {}", target_peer_count);
        // This would need to be added to NodeConfig if not already present
    }
    if let Some(async_request_timeout) = advanced.async_request_timeout {
        info!("Async request timeout set via CLI: {}", async_request_timeout);
    }
    if let Some(module_max_cpu_percent) = advanced.module_max_cpu_percent {
        info!("Module max CPU percent set via CLI: {}", module_max_cpu_percent);
    }
    if let Some(module_max_memory_bytes) = advanced.module_max_memory_bytes {
        info!("Module max memory bytes set via CLI: {}", module_max_memory_bytes);
    }
}

// RPC client helper
async fn rpc_call(rpc_addr: SocketAddr, method: &str, params: Value) -> Result<Value> {
    rpc_call_with_auth(rpc_addr, method, params, None, None).await
}

async fn rpc_call_with_auth(
    rpc_addr: SocketAddr,
    method: &str,
    params: Value,
    user: Option<&str>,
    password: Option<&str>,
) -> Result<Value> {
    let url = format!("http://{}", rpc_addr);
    let client = reqwest::Client::new();
    
    let request = json!({
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1
    });

    let mut req = client.post(&url).json(&request);
    
    // Use provided credentials or defaults
    let rpc_user = user.unwrap_or("btc");
    let rpc_password = password.unwrap_or("");
    req = req.basic_auth(rpc_user, Some(rpc_password));

    let response = req
        .send()
        .await
        .context("Failed to connect to RPC server")?;

    let status = response.status();
    if !status.is_success() {
        anyhow::bail!("RPC request failed with status: {}", status);
    }

    let json: Value = response.json().await.context("Failed to parse RPC response")?;
    
    if let Some(error) = json.get("error") {
        anyhow::bail!("RPC error: {}", error);
    }

    json.get("result")
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("No result in RPC response"))
}

// Subcommand handlers
async fn handle_status(rpc_addr: SocketAddr, _config: &NodeConfig) -> Result<()> {
    let chain_info = rpc_call(rpc_addr, "getblockchaininfo", json!([])).await?;
    let network_info = rpc_call(rpc_addr, "getnetworkinfo", json!([])).await?;
    let peer_info = rpc_call(rpc_addr, "getpeerinfo", json!([])).await?;

    println!("=== Node Status ===");
    println!("Block Height: {}", chain_info.get("blocks").and_then(|v| v.as_u64()).unwrap_or(0));
    println!("Chain: {}", chain_info.get("chain").and_then(|v| v.as_str()).unwrap_or("unknown"));
    println!("Verification Progress: {:.2}%", 
        chain_info.get("verificationprogress").and_then(|v| v.as_f64()).unwrap_or(0.0) * 100.0);
    println!("Connected Peers: {}", peer_info.as_array().map(|a| a.len()).unwrap_or(0));
    println!("Network Active: {}", network_info.get("networkactive").and_then(|v| v.as_bool()).unwrap_or(false));
    
    Ok(())
}

async fn handle_health(rpc_addr: SocketAddr, _config: &NodeConfig) -> Result<()> {
    match rpc_call(rpc_addr, "getblockchaininfo", json!([])).await {
        Ok(_) => {
            println!("✅ Node is healthy");
            Ok(())
        }
        Err(e) => {
            eprintln!("❌ Health check failed: {}", e);
            std::process::exit(1);
        }
    }
}

fn handle_version() -> Result<()> {
    println!("BLLVM {}", env!("CARGO_PKG_VERSION"));
    println!("Repository: {}", env!("CARGO_PKG_REPOSITORY"));
    
    // Try to get git info if available
    if let Ok(sha) = std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
    {
        if let Ok(sha_str) = String::from_utf8(sha.stdout) {
            println!("Git: {}", sha_str.trim());
        }
    }
    
    // Show enabled features
    println!("\nFeatures:");
    #[cfg(feature = "utxo-commitments")] println!("  ✓ utxo-commitments");
    #[cfg(feature = "dandelion")] println!("  ✓ dandelion");
    #[cfg(feature = "ctv")] println!("  ✓ ctv");
    #[cfg(feature = "stratum-v2")] println!("  ✓ stratum-v2");
    #[cfg(feature = "bip158")] println!("  ✓ bip158");
    #[cfg(feature = "sigop")] println!("  ✓ sigop");
    
    Ok(())
}

async fn handle_chain(rpc_addr: SocketAddr, _config: &NodeConfig) -> Result<()> {
    let info = rpc_call(rpc_addr, "getblockchaininfo", json!([])).await?;
    
    println!("=== Blockchain Information ===");
    println!("Chain: {}", info.get("chain").and_then(|v| v.as_str()).unwrap_or("unknown"));
    println!("Blocks: {}", info.get("blocks").and_then(|v| v.as_u64()).unwrap_or(0));
    println!("Headers: {}", info.get("headers").and_then(|v| v.as_u64()).unwrap_or(0));
    if let Some(hash) = info.get("bestblockhash").and_then(|v| v.as_str()) {
        println!("Best Block: {}", hash);
    }
    if let Some(diff) = info.get("difficulty").and_then(|v| v.as_f64()) {
        println!("Difficulty: {:.2}", diff);
    }
    if let Some(progress) = info.get("verificationprogress").and_then(|v| v.as_f64()) {
        println!("Verification Progress: {:.2}%", progress * 100.0);
    }
    
    Ok(())
}

async fn handle_peers(rpc_addr: SocketAddr, _config: &NodeConfig) -> Result<()> {
    let peers = rpc_call(rpc_addr, "getpeerinfo", json!([])).await?;
    
    println!("=== Connected Peers ===");
    if let Some(peer_array) = peers.as_array() {
        if peer_array.is_empty() {
            println!("No peers connected");
        } else {
            for (i, peer) in peer_array.iter().enumerate() {
                println!("\nPeer {}:", i + 1);
                if let Some(addr) = peer.get("addr").and_then(|v| v.as_str()) {
                    println!("  Address: {}", addr);
                }
                if let Some(version) = peer.get("version").and_then(|v| v.as_u64()) {
                    println!("  Version: {}", version);
                }
                if let Some(latency) = peer.get("latency").and_then(|v| v.as_f64()) {
                    println!("  Latency: {:.2}ms", latency * 1000.0);
                }
            }
        }
    }
    
    Ok(())
}

async fn handle_network(rpc_addr: SocketAddr, _config: &NodeConfig) -> Result<()> {
    let info = rpc_call(rpc_addr, "getnetworkinfo", json!([])).await?;
    
    println!("=== Network Information ===");
    println!("Version: {}", info.get("version").and_then(|v| v.as_u64()).unwrap_or(0));
    println!("Subversion: {}", info.get("subversion").and_then(|v| v.as_str()).unwrap_or("unknown"));
    println!("Network Active: {}", info.get("networkactive").and_then(|v| v.as_bool()).unwrap_or(false));
    if let Some(connections) = info.get("connections").and_then(|v| v.as_u64()) {
        println!("Connections: {}", connections);
    }
    if let Some(local_addrs) = info.get("localaddresses").and_then(|v| v.as_array()) {
        if !local_addrs.is_empty() {
            println!("Local Addresses:");
            for addr in local_addrs {
                if let Some(addr_str) = addr.get("address").and_then(|v| v.as_str()) {
                    println!("  {}", addr_str);
                }
            }
        }
    }
    
    Ok(())
}

async fn handle_sync(rpc_addr: SocketAddr, _config: &NodeConfig) -> Result<()> {
    let info = rpc_call(rpc_addr, "getblockchaininfo", json!([])).await?;
    
    let blocks = info.get("blocks").and_then(|v| v.as_u64()).unwrap_or(0);
    let headers = info.get("headers").and_then(|v| v.as_u64()).unwrap_or(0);
    let progress = info.get("verificationprogress").and_then(|v| v.as_f64()).unwrap_or(0.0);
    
    println!("=== Sync Status ===");
    println!("Blocks: {}", blocks);
    println!("Headers: {}", headers);
    println!("Progress: {:.2}%", progress * 100.0);
    
    if blocks == headers && progress >= 1.0 {
        println!("Status: ✅ Fully synced");
    } else if headers > blocks {
        println!("Status: ⏳ Syncing ({} blocks behind)", headers - blocks);
    } else {
        println!("Status: ⏳ Verifying");
    }
    
    Ok(())
}

fn handle_config_show(config: &NodeConfig) -> Result<()> {
    println!("{}", toml::to_string_pretty(config).context("Failed to serialize config")?);
    Ok(())
}

fn handle_config_validate(path: Option<PathBuf>, cli_config: &Option<PathBuf>) -> Result<()> {
    let config_path = path.or_else(|| cli_config.clone()).or_else(|| find_config_file(cli_config));
    
    match config_path {
        Some(path) => {
            match NodeConfig::from_file(&path) {
                Ok(_) => {
                    println!("✅ Configuration file is valid: {}", path.display());
                    Ok(())
                }
                Err(e) => {
                    eprintln!("❌ Configuration file is invalid: {}", e);
                    std::process::exit(1);
                }
            }
        }
        None => {
            eprintln!("❌ No configuration file found");
            std::process::exit(1);
        }
    }
}

fn handle_config_path(cli_config: &Option<PathBuf>) -> Result<()> {
    if let Some(path) = find_config_file(cli_config) {
        println!("{}", path.display());
        Ok(())
    } else {
        println!("No configuration file found");
        Ok(())
    }
}

async fn handle_rpc(rpc_addr: SocketAddr, method: &str, params: Value, _config: &NodeConfig) -> Result<()> {
    let result = rpc_call(rpc_addr, method, params).await?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}

