# Work Order: AA-261110-01 — Chain Verifier Hardening & RFC 8032 Courts

- **Key**: `AA-261110-01`
- **Milestone**: `v26.11.10`
- **Component**: `AshAffidavit.ChainVerifier`
- **Status**: IMPLEMENTED / VERIFIED
- **Type**: Feature / Security / Court

---

## 1. Problem Statement

Commit `ffc8dfd` introduced `lib/ash_affidavit/chain_verifier.ex` to support commercial settlement Ed25519 signature verification. However, prior to release qualification:
1. It lacked the required line 1 `# UNSUPPORTED(generator-capability): ...` header and SPDX license comments.
2. It lacked an entry in `HANDWRITTEN.md`, violating the Single Authority Law asserted by `test/ash_affidavit_extension_render_test.exs`.
3. It lacked support for unpadded Base64url and raw binary keys and signatures.
4. It lacked a dedicated ExUnit test court asserting RFC 8032 known-answer vectors and negative tamper/corruption test cases.

---

## 2. Implementation Summary

1. **Header & License Added**:
   Added line 1:
   ```elixir
   # UNSUPPORTED(generator-capability): no pack template emits standalone Ed25519 chain verifier
   # SPDX-FileCopyrightText: 2026 ash_affidavit contributors
   #
   # SPDX-License-Identifier: MIT
   ```
2. **Ledger Updated**:
   Added `lib/ash_affidavit/chain_verifier.ex` to `HANDWRITTEN.md`.
3. **Encoding Polymorphism Implemented**:
   Implemented robust decoding supporting raw binary 32-byte public keys and 64-byte signatures, standard Base64 (padded and unpadded), and Base64url (padded and unpadded).
4. **RFC 8032 Test Suite Authored**:
   Created `test/ash_affidavit_chain_verifier_test.exs` covering RFC 8032 Vectors 1 (empty payload), 2 (single-byte payload), and 3 (multi-byte payload), plus tamper invalidation tests (flipped bits, truncated signatures/keys, invalid base64, missing keys).

---

## 3. Verification Method & Output

```sh
MIX_BUILD_ROOT=_build-lane-m1 mix test test/ash_affidavit_extension_render_test.exs test/ash_affidavit_chain_verifier_test.exs
```
- ExtensionRenderTest: PASS (Single Authority Law verified).
- ChainVerifierTest: PASS (11/11 tests pass with zero failures).
