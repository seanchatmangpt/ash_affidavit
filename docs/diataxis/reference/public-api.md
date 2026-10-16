# Reference: Public API

Every entry verified against `lib/` in ash_affidavit 26.10.16. The engine
(affidavit v26.9.28, ABI 1) is vendored at `priv/affidavit/affidavit.wasm`,
pinned in `priv/affidavit/MANIFEST.json`.

## AshAffidavit

`lib/ash_affidavit.ex` — the hand-written public API over the generated host.

| function | returns |
|---|---|
| `call/2` | `{:ok, map}` \| `{:refused \| :trap \| :unsupported, %AshAffidavit.Refusal{}}` |
| `capabilities/1` | same result shape, for the `capabilities` op |
| `abi_version/0` | `pos_integer()` (from the contract, equal to the manifest `abi_version`) |
| `ops/0` | operation names from the engine capability registry |
| `registry/0` | decoded `priv/affidavit/capability-registry.json` |
| `authority_none?/1` | true when the response states no authority above NONE |

`call/2` takes a string-keyed (or atom-keyed) map carrying `"op"`, plus
options `:server` (a Host/Pool pid or name; default routes through
`AshAffidavit.Pool`) and `:timeout_ms`. A non-map request returns a
`missing_field` refusal rather than crashing (`lib/ash_affidavit.ex:72`).
`call/2` refuses (`:authority_escalation`) any `{:ok, _}` whose
`authority` — top level or inside `evidence` — is above NONE
(`lib/ash_affidavit.ex:132-143`).

### The nine engine ops

From `priv/affidavit/capability-registry.json` (`ops`):

- `capabilities` — the engine's op list
- `commit` — payload → commitment
- `assemble` — events → receipt (`chain_hash`, sequenced `events`)
- `verify` — receipt → `accepted` boolean
- `mine` — receipts → process model
- `conform` — receipts vs. a model
- `verify_signature_input` — signing-input check
- `certify_authzen_evidence`, `certify_spiffe_evidence` — external evidence
  certification (authority NONE, evidence only)

Request/response shapes: `priv/affidavit/op-examples.json`.

## Host and pool

`lib/ash_affidavit/host.ex` (generated), `lib/ash_affidavit/pool.ex` (generated):

- `AshAffidavit.Host.start_link/1` — one supervised Wasmtime instance. A
  missing or unloadable engine never fails the start; it becomes a typed
  refusal on every call. Options: `:name`, `:wasm_path`, `:bytes`,
  `:expected_sha256` (`:unpinned` opts out of the pin), `:fuel`,
  `:memory_limit_bytes`, `:recycle_bytes`, `:max_queue`,
  `:max_response_bytes`, `:timeout_ms`, `:registry`, `:retry_base_ms`,
  `:retry_max_ms`.
- `AshAffidavit.Host.request/3` — `request(server \\ __MODULE__, map, opts)`;
  returns the decoded response for both `"ok" => true` and `"ok" => false`;
  only transport/host failures are `{:error, %AshAffidavit.Refusal{}}`.
- `AshAffidavit.Host.available?/2`, `info/2`, `memory_size/2`.
- `AshAffidavit.Pool.start_link/1` — N supervised hosts behind one name,
  routing each request to the member with the shortest mailbox
  (`:rest_for_one`, registry first). Options `:name`, `:size` (default
  `System.schedulers_online/0`) plus any Host option.
- `AshAffidavit.Pool.request/2`, `AshAffidavit.Pool.size/1`,
  `AshAffidavit.Pool.registry/0`.

## Refusals

`lib/ash_affidavit/refusal.ex`:

- `AshAffidavit.Refusal` — an exception carrying `code`, `class`, `message`,
  `details`, `raw`. The code set is closed: host codes plus engine codes read
  at compile time from the registry's `error_codes`
  (`bad_json`, `missing_field`, `unknown_op`, `bad_field`, `too_large`,
  `too_deep`, `missing_buffer`, `internal`).
- `codes/0`, `engine_codes/0`, `class_of/1`, `outcome/1`, `new/3`,
  `from_engine/1`.

Classes: `:refused_input`, `:refused_identity`, `:refused_authority`,
`:blocked_resource`, `:trap`, `:unsupported`. Outcomes: `:refused`,
`:trap`, `:unsupported`. An unclassified engine code becomes
`:engine_unclassified` (class `:unsupported`), never a crash.

`lib/ash_affidavit/error/refused.ex`: `AshAffidavit.Error.Refused`, a
Splode error (class `:invalid`) wrapping a refusal, with `code/1` and
`outcome/1`.

## Engine admission and configuration

`lib/ash_affidavit/wasm_config.ex` and `lib/ash_affidavit/engine_load.ex`:

- Path resolution order: `:wasm_path` opt → env `AFFIDAVIT_WASM_PATH` →
  `config :ash_affidavit, :wasm_path` → vendored file
  (`AshAffidavit.WasmConfig.wasm_path/1`, `vendored_path/0`).
- Digest pin from `MANIFEST.json` (`sha256`
  `5cc37aea8e59f7139e2ff5d43ab3c3c82931285b6400cf45f943c61d21a41402`); the
  import surface must be exactly `environ_get`, `environ_sizes_get`,
  `fd_write`, `proc_exit` from `wasi_snapshot_preview1`; required exports
  `af_alloc`, `af_call`, `af_free`, `af_abi_version`, `memory`. Requests are
  capped at 16 MiB.
- Limits (`AshAffidavit.WasmConfig.limits/1`): `timeout_ms` 5000,
  `max_queue` 64, `memory_limit_bytes` 256 MiB, `recycle_bytes` 128 MiB,
  `max_response_bytes` 32 MiB, `fuel_per_ms` 1_000_000,
  `instantiate_fuel` 1e9, `table_elements` 100_000, `instances` 10,
  `tables` 10, `memories` 4. Override via
  `config :ash_affidavit, <limit>: pos_integer`.

## Mix tasks

- `mix ash_affidavit.install [--target MyApp.Resource]` —
  (`lib/mix/tasks/ash_affidavit.install.ex`) adds the `wasmex` dependency,
  the `import_deps` entry and the formatter plugin; with `--target`, the
  extension and a starter `affidavit do end` block. Idempotent.
- `mix ash_affidavit.vendor --check` — re-checks the vendored engine bytes
  against the manifest pin, without network access
  (`lib/mix/tasks/ash_affidavit.vendor.ex`).
- `mix ash_affidavit.verify` — full local verification
  (`lib/mix/tasks/ash_affidavit.verify.ex`).

## Ash extension modules

| module | use |
|---|---|
| `AshAffidavit.Resource` (`lib/ash_affidavit/resource.ex`) | Spark DSL: `affidavit do runtime do ... end; operation :name end` |
| `AshAffidavit.Resource.Info` | generated accessors (`compiled/1`, `compiled!/1`, `compiled?/1`) |
| `AshAffidavit.Resource.Declared` | `runtime/1`, `operations/1` over the normalized split |
| `AshAffidavit.Resource.Validate` | compile-time legality checks (unknown op, bad ceiling, timeout, hex keys, singleton/server) |
| `AshAffidavit.Change.Receipt` | run one op in an action; evidence at `changeset.context[:affidavit]` |
| `AshAffidavit.Validation.Verified` | attribute receipt must pass the `verify` op |
| `AshAffidavit.Calculation.Verdict` | per-record `:accept`/`:reject`/outcome atom |
| `AshAffidavit.Type.Receipt` | map with string keys `chain_hash`, `events` |
| `AshAffidavit.Type.ChainHash` | 64-hex digest, lowercased on input |
| `AshAffidavit.Notifier` | telemetry after an action that carried evidence |
| `AshAffidavit.Reactor.Step` | one op as a Reactor step; exists only when Reactor is loadable; `:trap` retries via `compensate/4` |

## Telemetry

- `[:ash_affidavit, :op, :stop]` — `%{duration: native_time}`,
  `%{op, outcome, code}` (from `AshAffidavit.Change.Receipt.run/2`).
- `[:ash_affidavit, :notifier, :action]` — `%{count: 1}`,
  `%{resource, action, evidence}` (from `AshAffidavit.Notifier`).

## See Also

`docs/diataxis/tutorials/run-your-first-receipt.md` ·
`docs/diataxis/how-to/use-the-ash-extension.md` ·
`docs/diataxis/explanation/outcomes-authority-and-refusals.md`
