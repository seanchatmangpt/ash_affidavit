# Work Order: AA-261110-02 — Parallel Test Suite Process Registry Isolation

- **Key**: `AA-261110-02`
- **Milestone**: `v26.11.10`
- **Component**: Testing / Concurrency / OTP
- **Status**: IMPLEMENTED / VERIFIED
- **Type**: Defect / Concurrency

---

## 1. Problem Statement

Under parallel ExUnit test execution (`max_cases: 32`), tests that started `AshAffidavit.Pool` via `start_supervised!/1` (such as `AshAffidavit.RefusalTest` or `AshAffidavit.OpReplayTest`) experienced intermittent collision failures:
```
** (RuntimeError) failed to start child with the spec {AshAffidavit.Pool, [size: 2]}.
Reason: bad child specification, got: {:already_started, #PID<...>}
```
Investigation revealed that `test/ash_affidavit_signing_courts_test.exs` invoked:
```elixir
{:ok, _} = AshAffidavit.Pool.start_link([])
```
inside its `setup_all` callback without supervision. The started GenServer was registered under the global atom `AshAffidavit.Pool` and remained alive even after the test module completed, leaking across module boundaries.

---

## 2. Implementation Summary

1. In `test/ash_affidavit_signing_courts_test.exs`:
   Replaced the unsupervised `AshAffidavit.Pool.start_link([])` with `start_supervised!({AshAffidavit.Pool, size: 2})`.
2. Removed redundant unlinked `AshAffidavit.Host.start_link` invocation.
3. ExUnit's supervisor now guarantees that the pool process is cleanly terminated immediately upon module completion.

---

## 3. Verification Method & Output

```sh
MIX_BUILD_ROOT=_build-lane-m1 mix test test/ash_affidavit_signing_courts_test.exs test/ash_affidavit_refusal_test.exs test/ash_affidavit_op_replay_test.exs
```
- All test suites pass 100% concurrently without `:already_started` collisions.
