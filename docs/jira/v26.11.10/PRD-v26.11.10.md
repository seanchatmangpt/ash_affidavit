# Product Requirements Document: ash_affidavit v26.11.10

- **Document ID**: `PRD-AA-261110`
- **Milestone**: `v26.11.10`
- **Component**: Product Management / Release Governance
- **Status**: IMPLEMENTED / GROUNDED

---

## 1. Product Overview

`ash_affidavit` brings verifiable cryptographic receipts, process-mining proofs, and digital signatures to the Ash ecosystem. It enables developers to integrate cryptographically tamper-evident audit trails directly into Ash resource lifecycles, actions, validations, and Reactor workflows.

Milestone `v26.11.10` focuses on enterprise settlement verification readiness, code hygiene, and strict packaging compliance for public Hex.pm distribution.

---

## 2. Target Personas & Use Cases

1. **Enterprise Settlement Engineers**:
   - Need to verify detached Ed25519 signatures over high-value settlement payloads before admitting transactions into financial ledgers.
   - Require support for diverse wire encodings (standard Base64, unpadded Base64url, and raw binary).
2. **Ash Framework Application Developers**:
   - Need declarative DSL extensions (`AshAffidavit.Resource`) to attach receipt verification to resource actions.
   - Demand zero-overhead when the engine is not configured, with strict type safety and structured error returns (`AshAffidavit.Refusal`).
3. **Platform & Site Reliability Engineers**:
   - Require predictable memory consumption, defensive worker pooling, clean process isolation, and pure telemetry spans (`[:ash_affidavit, :call]`) without web framework dependencies.

---

## 3. Product Features & Requirements

### FR-01: Commercial Settlement Ed25519 Chain Verifier
- **Description**: Provide `AshAffidavit.ChainVerifier.verify_settlement/1` to verify detached Ed25519 signatures over settlement payloads.
- **Inputs**: Map with keys `"payload"`, `"public_key"`, `"signature"` (or equivalent atom keys).
- **Supported Encodings**:
  - Raw 32-byte binary public keys and 64-byte binary signatures.
  - Standard Base64 encoded strings.
  - Padded and unpadded Base64url encoded strings.
- **Outputs**: `{:ok, :verified}` on success; `{:error, :invalid_ed25519_signature}` on any error or tamper condition.

### FR-02: Strict Code Quality & Credo Compliance
- **Description**: Ensure all source code adheres to strict Elixir style and complexity rules.
- **Requirement**: Zero Credo warnings under `--strict`, with cyclomatic complexity <= 9 and function nesting depth <= 2.

### FR-03: Concurrency Isolation in Parallel Test Suites
- **Description**: Prevent process collision in parallel ExUnit suites.
- **Requirement**: Guarantee that worker pools started in test fixtures are strictly supervised and terminated upon test module completion.

### FR-04: Accurate CalVer Carrier Synchronization
- **Description**: Synchronize release CalVer across all documentation and configuration carriers.
- **Requirement**: Version `26.11.10` declared uniformly across `mix.exs`, `README.md`, `CHANGELOG.md`, `usage-rules.md`, and Diataxis guides.

### FR-05: Clean Hex Package Closure
- **Description**: Ensure the Hex package archive includes only required production code, license files, and documentation.
- **Requirement**: No leaked development artifacts, git metadata, or build directories (`_build*`, `tmp`, `cover`).
