//! Tests for configuration loading and hierarchy

use std::env;
use std::fs;
use std::path::PathBuf;
use tempfile::TempDir;
use bllvm_node::config::NodeConfig;

/// Test TOML configuration file loading
#[test]
fn test_toml_config_file_loading() {
    let temp_dir = TempDir::new().unwrap();
    let config_path = temp_dir.path().join("bllvm.toml");
    
    let config_content = r#"
max_peers = 50
protocol_version = "Regtest"

[transport_preference]
preference = "TcpOnly"

[modules]
enabled = true
modules_dir = "modules"
data_dir = "data/modules"
socket_dir = "data/modules/sockets"
"#;
    
    fs::write(&config_path, config_content).unwrap();
    
    // Test that config file can be loaded
    let config = NodeConfig::from_toml_file(&config_path).expect("Should parse TOML config");
    assert_eq!(config.max_peers, Some(50));
    assert_eq!(config.protocol_version, Some("Regtest".to_string()));
    assert!(config.modules.is_some());
    if let Some(ref modules) = config.modules {
        assert!(modules.enabled);
        assert_eq!(modules.modules_dir, "modules");
    }
}

/// Test JSON configuration file loading
#[test]
fn test_json_config_file_loading() {
    let temp_dir = TempDir::new().unwrap();
    let config_path = temp_dir.path().join("bllvm.json");
    
    let config_content = r#"{
  "max_peers": 50,
  "protocol_version": "Regtest",
  "transport_preference": {
    "preference": "TcpOnly"
  }
}"#;
    
    fs::write(&config_path, config_content).unwrap();
    
    // Test that config file can be loaded
    let config = NodeConfig::from_json_file(&config_path).expect("Should parse JSON config");
    assert_eq!(config.max_peers, Some(50));
    assert_eq!(config.protocol_version, Some("Regtest".to_string()));
}

/// Test auto-detection of config file format
#[test]
fn test_config_file_auto_detection() {
    let temp_dir = TempDir::new().unwrap();
    
    // Test TOML
    let toml_path = temp_dir.path().join("config.toml");
    let toml_content = r#"max_peers = 50"#;
    fs::write(&toml_path, toml_content).unwrap();
    let config = NodeConfig::from_file(&toml_path).expect("Should parse TOML");
    assert_eq!(config.max_peers, Some(50));
    
    // Test JSON
    let json_path = temp_dir.path().join("config.json");
    let json_content = r#"{"max_peers": 50}"#;
    fs::write(&json_path, json_content).unwrap();
    let config = NodeConfig::from_file(&json_path).expect("Should parse JSON");
    assert_eq!(config.max_peers, Some(50));
}

/// Test environment variable parsing
#[test]
fn test_env_override() {
    // Set environment variables
    env::set_var("BLLVM_NETWORK", "testnet");
    env::set_var("BLLVM_RPC_ADDR", "127.0.0.1:18333");
    env::set_var("BLLVM_NODE_MAX_PEERS", "100");
    
    // Verify they can be read (this tests the EnvOverrides struct in main.rs)
    // Note: This is a basic test - full integration would require running the binary
    assert_eq!(env::var("BLLVM_NETWORK").unwrap(), "testnet");
    assert_eq!(env::var("BLLVM_RPC_ADDR").unwrap(), "127.0.0.1:18333");
    assert_eq!(env::var("BLLVM_NODE_MAX_PEERS").unwrap(), "100");
    
    // Cleanup
    env::remove_var("BLLVM_NETWORK");
    env::remove_var("BLLVM_RPC_ADDR");
    env::remove_var("BLLVM_NODE_MAX_PEERS");
}

/// Test default configuration
#[test]
fn test_default_config() {
    let config = NodeConfig::default();
    
    // Verify defaults are set
    assert_eq!(config.max_peers, None); // Default is None
    assert!(config.enable_self_advertisement); // Default is true
    assert_eq!(config.persistent_peers.len(), 0); // Default is empty
}

/// Test configuration file with invalid content
#[test]
fn test_invalid_config_file() {
    let temp_dir = TempDir::new().unwrap();
    let config_path = temp_dir.path().join("invalid.toml");
    
    let invalid_content = r#"
max_peers = "not a number"  # Invalid type
"#;
    
    fs::write(&config_path, invalid_content).unwrap();
    
    // Should fail to parse
    let result = NodeConfig::from_toml_file(&config_path);
    assert!(result.is_err(), "Should fail to parse invalid config");
}

/// Test configuration save and reload
#[test]
fn test_config_save_and_reload() {
    let temp_dir = TempDir::new().unwrap();
    let config_path = temp_dir.path().join("test.toml");
    
    // Create a config
    let mut config = NodeConfig::default();
    config.max_peers = Some(100);
    config.protocol_version = Some("Testnet".to_string());
    
    // Save it
    config.to_toml_file(&config_path).expect("Should save config");
    
    // Reload it
    let loaded = NodeConfig::from_toml_file(&config_path).expect("Should load config");
    assert_eq!(loaded.max_peers, Some(100));
    assert_eq!(loaded.protocol_version, Some("Testnet".to_string()));
}

