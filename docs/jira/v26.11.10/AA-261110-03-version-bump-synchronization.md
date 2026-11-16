# Work Order: AA-261110-03 — Version Bump Synchronization & Credo Strict

- **Key**: `AA-261110-03`
- **Milestone**: `v26.11.10`
- **Component**: Governance / Code Quality / CalVer
- **Status**: IMPLEMENTED / VERIFIED
- **Type**: Chore / Refactoring

---

## 1. Problem Statement

1. **Version Carriers Out of Sync**:
   `mix.exs` declared `@version "26.10.16"`, while the target milestone is `26.11.10`. Multiple documentation files still declared `26.10.16` or `26.10.8`.
2. **Credo Strict Failures**:
   `mix credo --strict` failed with exit code 8 due to 5 refactoring issues:
   - Single-clause `cond` in `AshAffidavit.Signing.Keys.b64url` and `AshAffidavit.Signing.derive_subject_digest`.
   - Function nesting depth (depth 3 vs max 2) in `AshAffidavit.Signing.derive_subject_digest`.
   - Cyclomatic complexity (12 and 10 vs max 9) in `AshAffidavit.Signing.algorithm_of` and `AshAffidavit.Signing.key_hex_of`.

---

## 2. Implementation Summary

1. **Version Bump**:
   Updated `@version "26.11.10"` in `mix.exs`.
   Synchronized `26.11.10` across:
   - `README.md`
   - `usage-rules/setup.md`
   - `documentation/tutorials/getting-started.md`
   - `docs/diataxis/README.md`
   - `docs/diataxis/how-to/signature-envelope.md`
   - `docs/diataxis/how-to/use-the-ash-extension.md`
   - `docs/diataxis/tutorials/run-your-first-receipt.md`
   - `docs/diataxis/reference/public-api.md`
   - `CHANGELOG.md` (added `[v26.11.10]` release entry).
2. **Credo Refactorings**:
   - Replaced single-clause `cond` with `if` in `b64url` and `derive_subject_digest`.
   - Extracted `decode_subject_digest_payload/2` to flatten nesting depth to <= 2.
   - Pattern-matched on `%{"version" => @envelope_version}` and extracted `extract_alg/2` in `algorithm_of` to reduce complexity from 12 to <= 3.
   - Extracted `extract_key_hex/2` and `extract_raw_key/2` in `key_hex_of` to reduce complexity from 10 to <= 3.

---

## 3. Verification Method & Output

```sh
MIX_BUILD_ROOT=_build-lane-m1 mix credo --strict
```
- Credo strict reports 0 errors, 0 warnings, 0 refactoring opportunities. Exit code 0.
