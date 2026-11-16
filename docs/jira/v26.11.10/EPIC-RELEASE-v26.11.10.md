# Release Epic: ash_affidavit v26.11.10

- **Epic Key**: `EPIC-AA-261110`
- **Milestone**: `v26.11.10`
- **Repository**: `seanchatmangpt/ash_affidavit`
- **Status**: IMPLEMENTED / READY FOR MAINTAINER TAG
- **Authority Ceiling**: `:NONE` (Zero unreceipted actuation; live Hex publication requires maintainer API key)

---

## 1. Objective

Deliver a hardened, production-ready Hex release `v26.11.10` of `ash_affidavit` featuring:
1. Landed and verified detached Ed25519 commercial settlement cryptographic signature and pre-image chain verifier (`AshAffidavit.ChainVerifier`).
2. Single Authority Law enforcement across all `lib/` files.
3. Clean ExUnit concurrency isolation eliminating process registry leaks.
4. Zero Credo strict warnings across all signing and key handling surfaces.
5. CalVer `26.11.10` synchronization across all carriers.
6. Clean ExDoc generation and removal of taxonomy violations (`generated/` -> `descriptors/`).
7. Full 10-persona domain evaluation suite demonstrating compliance with best practices in distributed systems, functional purity, and epistemic receipt architecture.

---

## 2. Invariants & Fences

1. **The Chatman Equation ($A = \mu(O^*), R = receipt(A)$)**:
   - All receipts are immutable, cryptographic facts derived from exact subjects.
   - Authority ceiling `:NONE` is strictly maintained (`authority_none?/1`).
2. **Single Authority Law**:
   - Every file in `lib/` is either projected from an RDF ontology pack or carries the explicit `# UNSUPPORTED(generator-capability)` header and a recorded row in `HANDWRITTEN.md`.
3. **Chicago-School Zero-Mock Discipline**:
   - Tests execute against the real vendored Wasm binary (`priv/affidavit/affidavit.wasm`) and real crypto primitives (`:crypto.verify/5`). No mocks, stubs, or facades.
4. **Hex Publishing Governance**:
   - In accordance with `AGENTS.md:57`, agent sessions never invoke live `mix hex.publish`. Packaging and dry-run validation are executed via `mix hex.build --unpack`, `mix hex.build`, and `mix hex.publish --dry-run --yes < /dev/null`.

---

## 3. Scope of Work Orders

| Order | Title | Target Artifacts | Status |
|---|---|---|---|
| `AA-261110-01` | ChainVerifier Hardening & RFC 8032 Courts | `lib/ash_affidavit/chain_verifier.ex`, `HANDWRITTEN.md`, `test/ash_affidavit_chain_verifier_test.exs` | IMPLEMENTED |
| `AA-261110-02` | Parallel Test Suite Process Registry Isolation | `test/ash_affidavit_signing_courts_test.exs` | IMPLEMENTED |
| `AA-261110-03` | CalVer 26.11.10 Synchronization & Credo Strict | `mix.exs`, `CHANGELOG.md`, `README.md`, `usage-rules.md`, Diataxis guides, `lib/ash_affidavit/signing.ex`, `signing/keys.ex` | IMPLEMENTED |
| `AA-261110-04` | Hex Publish Readiness & Packaging Courts | `mix.exs`, `.gitignore`, `HEX-RELEASE-COURT-RECEIPT.md` | VERIFIED |
| `AA-261110-05` | 10-Agent Luminary Swarm Review & Synthesis | `evaluations/EVAL-01` to `EVAL-10`, `SWARM-REVIEW-SYNTHESIS.md` | APPROVED |

---

## 4. Acceptance Criteria

1. **Compilation**: `mix compile --warnings-as-errors` passes exit 0.
2. **Code Style**: `mix format --check-formatted` passes exit 0.
3. **Static Analysis**: `mix credo --strict` passes with 0 issues; `MIX_ENV=test mix sobelow --skip` reports 0 vulnerabilities.
4. **Wasm & Tests**: `mix ash_affidavit.verify` verifies pinned Wasm SHA-256; `mix test` executes all unit and court tests with 0 failures.
5. **Documentation**: `mix docs --warnings-as-errors` produces complete documentation with 0 warnings.
6. **Hex Package**: `mix hex.build --unpack` confirms 100% whitelist packaging closure with zero build/git artifact leaks; `mix hex.publish --dry-run --yes < /dev/null` exits 0.
