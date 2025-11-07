# Build Policy (Org-Level)

## Separation of Concerns
- **commons**: Orchestration, policies, reusable workflows, shared tools, version topology.
- **bllvm-consensus (L2)**: Consensus math + formal verification; publishes libraries and verification bundles.
- **bllvm-protocol (L3)**: Protocol abstraction; depends on L2; publishes library.
- **bllvm-node (L4)**: Node infra; depends on L2 & L3; publishes binaries.

## Build Order
1. bllvm-consensus → verify (tests + optional Kani)
2. bllvm-protocol → build lib
3. bllvm-node → build binaries

## Version Topology
- Authoritative map: `commons/versions.toml` (tags per repo).
- Orchestrator reads this file to pin repos.

## Workflows
- Reusable: `.github/workflows/verify_consensus.yml`, `build_lib.yml`.
- Orchestrator: `.github/workflows/release_orchestrator.yml`.

## Deterministic Builds
- Each repo maintains `rust-toolchain.toml`.
- Builds use `--locked` and fixed toolchain.
- Hash artifacts with `SHA256SUMS`.

## Attestation
- Verification bundles produced by L2 (tests + kani + logs).
- Attestations stored in governance repo (or commons/attestations/).
