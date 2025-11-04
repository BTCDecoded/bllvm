# Security Policy

This document covers repo-specific security boundaries. See the [BTCDecoded Security Policy](https://github.com/BTCDecoded/.github/blob/main/SECURITY.md) for organization-wide policy.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**This repository contains build orchestration and release automation for the entire Bitcoin Commons ecosystem. Security vulnerabilities could affect all repositories and releases.**

### Critical Security Issues

If you discover a security vulnerability in commons, please report it immediately:

1. **DO NOT** create a public GitHub issue
2. **DO NOT** discuss the vulnerability publicly
3. **DO NOT** post on social media or forums

### How to Report

**Email:** security@btcdecoded.org  
**Subject:** [SECURITY] commons vulnerability

Include the following information:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### Response Timeline

- **Acknowledgment:** Within 24 hours
- **Initial Assessment:** Within 72 hours
- **Fix Development:** 1-2 weeks (depending on severity)
- **Public Disclosure:** Coordinated with fix release

### Vulnerability Types

#### Critical (P0)
- Build script injection vulnerabilities
- Version coordination tampering
- Release artifact corruption
- Workflow security bypasses
- Supply chain attacks

#### High (P1)
- Script execution vulnerabilities
- Configuration file parsing issues
- Authentication/authorization bypasses
- Information disclosure

#### Medium (P2)
- Performance issues
- Documentation errors
- Non-critical script errors

### Security Considerations

#### Build Script Security
- All scripts must validate inputs
- No command injection vulnerabilities
- Proper file path sanitization
- Secure temporary file handling

#### Version Coordination
- Version files must be validated
- No tampering with version mappings
- Secure version file distribution
- Integrity checks on version data

#### Workflow Security
- GitHub Actions workflows must be secure
- No secrets in workflow files
- Proper authentication for API calls
- Secure artifact handling

### Testing Requirements

Before reporting, please verify:
- [ ] The issue reproduces consistently
- [ ] The issue affects build or release processes
- [ ] The issue is not already known
- [ ] The issue is not a feature request

### Security Updates

Security updates will be:
- Released as patch versions (0.1.x)
- Clearly marked as security fixes
- Backported to all supported versions
- Announced on our security mailing list

### Contact Information

- **Security Team:** security@btcdecoded.org
- **General Inquiries:** info@btcdecoded.org
- **Website:** https://btcdecoded.org

### Acknowledgments

We thank the security researchers who help keep the Bitcoin Commons ecosystem secure through responsible disclosure.

---

**Remember:** This repository orchestrates builds and releases for the entire Bitcoin Commons ecosystem. Any vulnerabilities could affect all repositories. Please report responsibly.

