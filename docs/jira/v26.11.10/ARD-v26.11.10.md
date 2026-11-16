# Architecture Requirements Document: ash_affidavit v26.11.10

- **Document ID**: `ARD-AA-261110`
- **Milestone**: `v26.11.10`
- **Component**: Architecture / System Invariants
- **Status**: IMPLEMENTED / GROUNDED

---

## 1. Architectural Philosophy & Context

`ash_affidavit` is an Ash Framework and Elixir extension binding the pinned `affidavit` WebAssembly engine (`priv/affidavit/affidavit.wasm`). It produces, validates, and records tamper-evident cryptographic settlement receipts, process-mining proofs, and verification envelopes across commercial and transactional state boundaries.

Under the Chatman Equation:
$$A = \mu(O^*), \quad R = receipt(A)$$
- Observations ($O^*$) are ground-truth facts: pinned Wasm digests, cryptographically attested signatures, and deterministic action parameters.
- Manufacture ($\mu$) is lawful execution: bounded execution within Wasm sandbox instances without side-effects or external network calls.
- Receipts ($R$) are immutable cryptographic structures carrying identity, authority, consequence, replayability, and standing.

---

## 2. Subsystem Architecture

### 2.1 The Ed25519 Chain Verifier (`AshAffidavit.ChainVerifier`)
The commercial settlement surface requires detached Ed25519 signature verification over serialized settlement payloads.
- **Algorithm**: Ed25519 (RFC 8032), 32-byte public keys, 64-byte detached signatures.
- **Encoding Polymorphism**: Automatically accommodates:
  - Raw binary (`byte_size(key) == 32`, `byte_size(sig) == 64`).
  - Standard Base64 (`Base.decode64/1`).
  - Unpadded or padded Base64url (`Base.url_decode64/2`).
- **Fail-Closed Security**: Any malformed Base64, non-binary payload, truncated key/signature, bit flip, or signature verification failure returns `{:error, :invalid_ed25519_signature}`. Exceptions are never raised to caller code.

### 2.2 Wasm Host Sandbox & Pool Management (`AshAffidavit.Host` & `AshAffidavit.Pool`)
- **Isolation**: Each Wasm runtime executes within an isolated memory sandbox via `wasmex`.
- **Worker Pool**: `AshAffidavit.Pool` coordinates a pool of warm Wasm hosts, preventing resource exhaustion while providing low-latency adjudication.
- **Resource Limits**: Configured in `AshAffidavit.WasmConfig` with hard ceilings (16 MiB request ceiling, timeout limits, instance memory recycling).

### 2.3 Single Authority Law & Fence Discipline
The codebase maintains strict boundaries between generated projections and handwritten residue:
- **Projection Source**: `ontology/affidavit-binding.ttl` and `ontology/affidavit-extension.ttl`.
- **Generated Host**: `lib/ash_affidavit/{abi,wasm_config,engine_load,host,pool}.ex`.
- **Generated Extension**: `lib/ash_affidavit/{resource,persist,verify,info}.ex`.
- **Handwritten Residue**: Every non-projected file in `lib/` must declare `# UNSUPPORTED(generator-capability): ...` on line 1 and maintain an entry in `HANDWRITTEN.md`.
- **Court Enforcement**: `test/ash_affidavit_extension_render_test.exs` asserts this law across all files in `lib/`.

### 2.4 Process Isolation & Concurrency
- Test suites running under ExUnit concurrency must not leak global names.
- Subprocesses registered with global atoms (e.g., `AshAffidavit.Pool`) must be linked to the ExUnit test runner using `ExUnit.Callbacks.start_supervised!/2` to ensure guaranteed cleanup on exit.

---

## 3. Security Architecture

1. **Authority Ceilings**:
   - `AshAffidavit` explicitly operates with `authorityClaim :NONE`.
   - Any engine response claiming an authority above `:NONE` is rejected as an authority escalation refusal (`:refused_authority`).
2. **Deterministic Adjudication**:
   - The Wasm engine has zero access to host system calls, clock, filesystem, or network.
   - All cryptographic settlement adjudications are pure mathematical transformations.
3. **No Dynamic Code Evaluation**:
   - Client-provided arguments cannot influence module dispatch or execute untrusted code.
