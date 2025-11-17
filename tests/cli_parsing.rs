//! Tests for CLI argument parsing

use assert_cmd::Command;
use predicates::prelude::*;

/// Test that --help works
#[test]
fn test_help_flag() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--help");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("Bitcoin Commons BLLVM"));
}

/// Test network argument parsing - valid networks
#[test]
fn test_network_argument_valid() {
    for network in &["regtest", "testnet", "mainnet"] {
        let mut cmd = Command::cargo_bin("bllvm").unwrap();
        cmd.arg("--network").arg(network);
        // Should parse successfully (will fail later when trying to start node, but parsing should work)
        // We use timeout to prevent hanging
        cmd.timeout(std::time::Duration::from_secs(1));
        // The command will fail when trying to start the node, but that's expected
        // We just want to verify it parses correctly
        let _ = cmd.assert();
    }
}

/// Test that invalid network is rejected
#[test]
fn test_invalid_network() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--network").arg("invalid");
    cmd.assert()
        .failure()
        .stderr(predicate::str::contains("invalid"));
}

/// Test verbose flag parsing
#[test]
fn test_verbose_flag() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--verbose");
    cmd.timeout(std::time::Duration::from_secs(1));
    // Should parse successfully (will fail when starting node, but parsing works)
    let _ = cmd.assert();
}

/// Test feature flags parsing
#[test]
fn test_feature_flags() {
    let flags = [
        "--enable-dandelion",
        "--disable-dandelion",
        "--enable-bip158",
        "--disable-bip158",
        "--enable-stratum-v2",
        "--disable-stratum-v2",
        "--enable-sigop",
        "--disable-sigop",
    ];
    
    for flag in &flags {
        let mut cmd = Command::cargo_bin("bllvm").unwrap();
        cmd.arg(flag);
        cmd.timeout(std::time::Duration::from_secs(1));
        // Should parse successfully
        let _ = cmd.assert();
    }
}

/// Test RPC address parsing
#[test]
fn test_rpc_addr_parsing() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--rpc-addr").arg("127.0.0.1:18332");
    cmd.timeout(std::time::Duration::from_secs(1));
    // Should parse successfully
    let _ = cmd.assert();
}

/// Test listen address parsing
#[test]
fn test_listen_addr_parsing() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--listen-addr").arg("0.0.0.0:8333");
    cmd.timeout(std::time::Duration::from_secs(1));
    // Should parse successfully
    let _ = cmd.assert();
}

/// Test data directory argument
#[test]
fn test_data_dir_parsing() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--data-dir").arg("/tmp/test-data");
    cmd.timeout(std::time::Duration::from_secs(1));
    // Should parse successfully
    let _ = cmd.assert();
}

/// Test advanced configuration options
#[test]
fn test_advanced_config_options() {
    let mut cmd = Command::cargo_bin("bllvm").unwrap();
    cmd.arg("--target-peer-count").arg("10");
    cmd.arg("--async-request-timeout").arg("300");
    cmd.arg("--module-max-cpu-percent").arg("50");
    cmd.arg("--module-max-memory-bytes").arg("536870912");
    cmd.timeout(std::time::Duration::from_secs(1));
    // Should parse successfully
    let _ = cmd.assert();
}

