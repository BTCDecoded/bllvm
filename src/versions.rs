//! versions.toml parsing and validation

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

/// Version information for a repository
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RepoVersion {
    /// Semantic version (e.g., "0.1.0")
    pub version: String,
    
    /// Git tag (e.g., "v0.1.0")
    pub git_tag: String,
    
    /// Git commit hash (optional)
    #[serde(default)]
    pub git_commit: Option<String>,
    
    /// Required dependencies with version constraints
    #[serde(default)]
    pub requires: Vec<String>,
    
    /// Binary names produced by this repo
    #[serde(default)]
    pub binaries: Vec<String>,
}

/// Versions manifest structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VersionsManifest {
    /// Repository versions
    #[serde(rename = "versions")]
    pub versions: HashMap<String, RepoVersion>,
    
    /// Metadata
    #[serde(default)]
    pub metadata: Option<HashMap<String, String>>,
}

impl VersionsManifest {
    /// Load versions.toml from file
    pub fn from_file<P: AsRef<Path>>(path: P) -> anyhow::Result<Self> {
        let content = std::fs::read_to_string(path.as_ref())
            .map_err(|e| anyhow::anyhow!("Failed to read versions.toml: {}", e))?;
        
        let manifest: VersionsManifest = toml::from_str(&content)
            .map_err(|e| anyhow::anyhow!("Failed to parse versions.toml: {}", e))?;
        
        Ok(manifest)
    }
    
    /// Validate the manifest
    pub fn validate(&self) -> ValidationResult {
        let mut errors = Vec::new();
        let mut warnings = Vec::new();
        
        // Check all versions are valid semver
        for (repo, version_info) in &self.versions {
            if !is_valid_semver(&version_info.version) {
                errors.push(format!(
                    "Repository '{}' has invalid version '{}' (must be X.Y.Z)",
                    repo, version_info.version
                ));
            }
            
            // Check dependencies exist
            for dep in &version_info.requires {
                let dep_name = dep.split('=').next().unwrap_or(dep);
                if !self.versions.contains_key(dep_name) {
                    errors.push(format!(
                        "Repository '{}' requires '{}' which is not defined",
                        repo, dep_name
                    ));
                }
            }
        }
        
        // Check for circular dependencies
        if let Some(circular) = self.detect_circular_dependencies() {
            errors.push(format!("Circular dependency detected: {}", circular));
        }
        
        if errors.is_empty() && warnings.is_empty() {
            ValidationResult::Valid
        } else if errors.is_empty() {
            ValidationResult::ValidWithWarnings(warnings)
        } else {
            ValidationResult::Invalid { errors, warnings }
        }
    }
    
    /// Detect circular dependencies
    pub fn detect_circular_dependencies(&self) -> Option<String> {
        for (repo, _) in &self.versions {
            let mut visited = std::collections::HashSet::new();
            let mut path = Vec::new();
            if self.has_circular_dependency(repo, &mut visited, &mut path) {
                return Some(path.join(" -> "));
            }
        }
        None
    }
    
    fn has_circular_dependency(
        &self,
        repo: &str,
        visited: &mut std::collections::HashSet<String>,
        path: &mut Vec<String>,
    ) -> bool {
        if path.contains(&repo.to_string()) {
            path.push(repo.to_string());
            return true;
        }
        
        if visited.contains(repo) {
            return false;
        }
        
        visited.insert(repo.to_string());
        path.push(repo.to_string());
        
        if let Some(version_info) = self.versions.get(repo) {
            for dep in &version_info.requires {
                let dep_name = dep.split('=').next().unwrap_or(dep);
                if self.has_circular_dependency(dep_name, visited, path) {
                    return true;
                }
            }
        }
        
        path.pop();
        false
    }
    
    /// Get build order (topological sort)
    pub fn build_order(&self) -> anyhow::Result<Vec<String>> {
        let mut result = Vec::new();
        let mut visited = std::collections::HashSet::new();
        let mut visiting = std::collections::HashSet::new();
        
        for repo in self.versions.keys() {
            if !visited.contains(repo) {
                self.dfs(repo, &mut visited, &mut visiting, &mut result)?;
            }
        }
        
        Ok(result)
    }
    
    fn dfs(
        &self,
        repo: &str,
        visited: &mut std::collections::HashSet<String>,
        visiting: &mut std::collections::HashSet<String>,
        result: &mut Vec<String>,
    ) -> anyhow::Result<()> {
        if visiting.contains(repo) {
            anyhow::bail!("Circular dependency detected involving {}", repo);
        }
        if visited.contains(repo) {
            return Ok(());
        }
        
        visiting.insert(repo.to_string());
        
        if let Some(version_info) = self.versions.get(repo) {
            for dep in &version_info.requires {
                let dep_name = dep.split('=').next().unwrap_or(dep);
                self.dfs(dep_name, visited, visiting, result)?;
            }
        }
        
        visiting.remove(repo);
        visited.insert(repo.to_string());
        result.push(repo.to_string());
        Ok(())
    }
}

/// Validation result
#[derive(Debug, Clone)]
pub enum ValidationResult {
    Valid,
    ValidWithWarnings(Vec<String>),
    Invalid {
        errors: Vec<String>,
        warnings: Vec<String>,
    },
}

impl ValidationResult {
    pub fn is_valid(&self) -> bool {
        matches!(self, ValidationResult::Valid | ValidationResult::ValidWithWarnings(_))
    }
    
    pub fn errors(&self) -> &[String] {
        match self {
            ValidationResult::Invalid { errors, .. } => errors,
            _ => &[],
        }
    }
}

/// Check if a version string is valid semantic versioning (X.Y.Z)
fn is_valid_semver(version: &str) -> bool {
    let parts: Vec<&str> = version.split('.').collect();
    if parts.len() != 3 {
        return false;
    }
    parts.iter().all(|part| part.parse::<u32>().is_ok())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_valid_semver() {
        assert!(is_valid_semver("0.1.0"));
        assert!(is_valid_semver("1.2.3"));
        assert!(is_valid_semver("10.20.30"));
        assert!(!is_valid_semver("1.2"));
        assert!(!is_valid_semver("v1.2.3"));
        assert!(!is_valid_semver("1.2.3.4"));
    }
    
    #[test]
    fn test_parse_versions_toml() {
        let content = r#"
[versions]
bllvm-consensus = { version = "0.1.0", git_tag = "v0.1.0" }
bllvm-protocol = { version = "0.1.0", git_tag = "v0.1.0", requires = ["bllvm-consensus=0.1.0"] }
"#;
        
        let manifest: VersionsManifest = toml::from_str(content).unwrap();
        assert_eq!(manifest.versions.len(), 2);
        assert!(manifest.versions.contains_key("bllvm-consensus"));
        assert!(manifest.versions.contains_key("bllvm-protocol"));
    }
    
    #[test]
    fn test_build_order() {
        let content = r#"
[versions]
bllvm-consensus = { version = "0.1.0", git_tag = "v0.1.0" }
bllvm-protocol = { version = "0.1.0", git_tag = "v0.1.0", requires = ["bllvm-consensus=0.1.0"] }
bllvm-node = { version = "0.1.0", git_tag = "v0.1.0", requires = ["bllvm-protocol=0.1.0"] }
"#;
        
        let manifest: VersionsManifest = toml::from_str(content).unwrap();
        let order = manifest.build_order().unwrap();
        
        let consensus_pos = order.iter().position(|r| r == "bllvm-consensus").unwrap();
        let protocol_pos = order.iter().position(|r| r == "bllvm-protocol").unwrap();
        let node_pos = order.iter().position(|r| r == "bllvm-node").unwrap();
        
        assert!(consensus_pos < protocol_pos);
        assert!(protocol_pos < node_pos);
    }
    
    #[test]
    fn test_circular_dependency_detection() {
        let content = r#"
[versions]
A = { version = "0.1.0", git_tag = "v0.1.0", requires = ["B=0.1.0"] }
B = { version = "0.1.0", git_tag = "v0.1.0", requires = ["A=0.1.0"] }
"#;
        
        let manifest: VersionsManifest = toml::from_str(content).unwrap();
        assert!(manifest.detect_circular_dependencies().is_some());
    }
}

