# Contributing to Bitcoin Commons

Thank you for your interest in contributing to the Bitcoin Commons build and release system! This document contains repo-specific guidelines. See the [BTCDecoded Contribution Guide](https://github.com/BTCDecoded/.github/blob/main/CONTRIBUTING.md) for general guidelines.

## Code of Conduct

This project follows the [Rust Code of Conduct](https://www.rust-lang.org/policies/code-of-conduct). By participating, you agree to uphold this code.

## How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to avoid duplicates
2. **Check the documentation** to ensure it's not a usage question
3. **Verify the issue** with the latest version

For security issues, see [SECURITY.md](SECURITY.md).

### Submitting Pull Requests

1. **Fork the repository**
2. **Create a feature branch** from `main`
3. **Make your changes** following our guidelines
4. **Test your changes** with the build system
5. **Update documentation** as needed
6. **Submit a pull request**

## Development Guidelines

### Build Script Changes

The `build.sh` script is critical for the entire Bitcoin Commons ecosystem:

- **Test thoroughly** - Changes affect all repositories
- **Maintain backward compatibility** - Don't break existing workflows
- **Document new features** - Update README and BUILD_SYSTEM.md
- **Follow bash best practices** - Use `set -euo pipefail`, proper error handling

### Version Coordination

When modifying `versions.toml`:

- **Coordinate with all repos** - Ensure compatibility
- **Update metadata fields** - Fill in `last_updated`, `updated_by`, `release_notes`
- **Test version validation** - Run `verify-versions.sh`
- **Document breaking changes** - If version requirements change

### Workflow Changes

For GitHub Actions workflows:

- **Test locally first** - Use `act` or similar tools when possible
- **Maintain reusability** - Workflows are used by other repos
- **Document inputs/outputs** - Clear parameter descriptions
- **Version workflow calls** - Use specific tags/commits for stability

### Script Standards

All scripts should:

- Use `#!/bin/bash` with `set -euo pipefail`
- Include proper error messages
- Support `--help` flags
- Follow consistent naming conventions
- Include inline documentation

## Development Setup

### Prerequisites

- Bash 4.0+
- Git
- Access to Bitcoin Commons repositories (for testing)

### Testing Build Scripts

```bash
# Test build script
./build.sh --mode dev

# Test version verification
./scripts/verify-versions.sh

# Test artifact collection
./scripts/collect-artifacts.sh --test
```

## Commit Message Format

Use conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `ci`: CI/CD changes
- `build`: Build system changes

**Examples:**
```
feat(build): add support for cross-compilation
fix(versions): correct dependency version parsing
docs(readme): update build instructions
ci(workflows): add version validation job
```

## Review Process

### Pull Request Requirements

- [ ] **Build scripts tested** - Verified with local repos
- [ ] **Documentation updated** - README and relevant docs
- [ ] **Version coordination** - Updated versions.toml if needed
- [ ] **Workflows tested** - GitHub Actions workflows work
- [ ] **Backward compatible** - Doesn't break existing usage

### Review Criteria

Reviewers will check:

1. **Correctness** - Does the code work as intended?
2. **Compatibility** - Does it work with all repos?
3. **Documentation** - Is it clear and complete?
4. **Testing** - Are changes properly tested?
5. **Security** - Any potential vulnerabilities?

## Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to build system or workflows
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Release Checklist

- [ ] **All scripts tested**
- [ ] **Documentation updated**
- [ ] **Version coordination updated**
- [ ] **Workflows verified**
- [ ] **Release notes prepared**

## Getting Help

- **Documentation**: Check the README and BUILD_SYSTEM.md
- **Issues**: Search existing issues or create new ones
- **Discussions**: Use GitHub Discussions for questions
- **Security**: See [SECURITY.md](SECURITY.md)

## Questions?

If you have questions about contributing, please:

1. **Check this document** first
2. **Search existing issues** for similar questions
3. **Create a new issue** with the "question" label

Thank you for contributing to Bitcoin Commons! 🚀

