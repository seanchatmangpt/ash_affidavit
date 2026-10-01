<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# Testing with AshAffidavit

- Test against the real pinned wasm. Start the pool with
  `start_supervised!({AshAffidavit.Pool, size: 2})` in `setup_all`. Do not mock `AshAffidavit.call/2`.
- Assert on final state: the record, the changeset context, the returned refusal code. Do not assert
  on call counts.
- Use a real ETS-backed Ash resource (`data_layer: Ash.DataLayer.Ets`, `private? true`) for action
  tests. See `test/support/affidavit_resource.ex`.
- Test DSL errors by compiling a real embedded resource with `Code.compile_string/1` and running
  the verifier `AshAffidavit.Resource.Verify` (its `verify/1`) over `module.spark_dsl_config()`.
- Tests that need `ASH_AFFIDAVIT_PACK_ROOT` carry `@tag :pack_root` and are excluded when it is unset.
