# How To: Attach Engine Receipts to Ash Resources

Goal: record an engine affidavit alongside your records, validate receipts on
write, and expose a per-record verdict — using the `AshAffidavit.Resource`
extension and its Ash integrations.

## Prerequisites

- `ash_affidavit` 26.10.1 with the pool running
  (`config :ash_affidavit, start_pool: true`).
- An Ash domain. This guide mirrors the tested fixture at
  `test/support/affidavit_resource.ex`.

## 1. Extend the resource

```elixir
defmodule MyApp.Build do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshAffidavit.Resource]

  affidavit do
    runtime do
      timeout_ms 2_000
    end

    operation :commit
    operation :verify
  end
end
```

The `affidavit` section (defined in `lib/ash_affidavit/resource.ex`)
accepts one `runtime` entity (`wasm_path`, `timeout_ms`, `trusted_keys`,
`server`, `singleton`) and any number of `operation` entities. The name
must be a member of `AshAffidavit.ops/0` and the ceiling one of
`:observe | :select | :construct` — checked at compile time by
`AshAffidavit.Resource.Validate` (`lib/ash_affidavit/resource/validate.ex`).
Declaring a ceiling grants no authority.

Read a declaration back with the generated accessors
(`AshAffidavit.Resource.Info.compiled/1`) or the normalized split
`AshAffidavit.Resource.Declared.runtime/1` and
`AshAffidavit.Resource.Declared.operations/1`
(`lib/ash_affidavit/resource/declared.ex`).

## 2. Store engine evidence on create

Add `AshAffidavit.Change.Receipt` to an action
(`lib/ash_affidavit/change/receipt.ex`):

```elixir
actions do
  create :record do
    accept [:name]
    change {AshAffidavit.Change.Receipt, op: :commit, request: &__MODULE__.commit_request/1}
  end
end

def commit_request(changeset),
  do: %{"payload" => Ash.Changeset.get_attribute(changeset, :name)}
```

Options (`init/1` validates them at compile time): `:op` (required,
member of `AshAffidavit.ops/0`), `:request` (arity-1 changeset function;
defaults to `changeset.context[:affidavit_request]`), `:phase`
(`:before_action` default or `:before_transaction`), `:server`,
`:timeout`, and `:into` (context key, default `:affidavit`).

On `{:ok, response}` the response map is stored at
`changeset.context[:affidavit]`. Any `:refused`/`:trap`/`:unsupported`
outcome adds an `AshAffidavit.Error.Refused` to the changeset, so the
action fails while the typed refusal stays recoverable via
`AshAffidavit.Error.Refused.code/1` and `outcome/1`.

The change is not atomic (`atomic/3` returns `{:not_atomic, _}`): use
`strategy: :stream` for `Ash.bulk_update/4`, not `:atomic`.

Every call emits telemetry `[:ash_affidavit, :op, :stop]` with
`%{duration: native_time}` and `%{op: op, outcome: outcome, code: code}`.

## 3. Keep the receipt on the record

`AshAffidavit.Type.Receipt` (`lib/ash_affidavit/type/receipt.ex`) casts a
map with string keys `"chain_hash"` and `"events"` — exactly the shape
the engine's `assemble` op returns. `AshAffidavit.Type.ChainHash`
(`lib/ash_affidavit/type/chain_hash.ex`) casts a 64-hex-character digest,
lowercasing input.

```elixir
attributes do
  uuid_primary_key :id
  attribute :receipt, AshAffidavit.Type.Receipt, public?: true
  attribute :chain_hash, AshAffidavit.Type.ChainHash, public?: true
end
```

## 4. Verify receipts on write

`AshAffidavit.Validation.Verified` (`lib/ash_affidavit/validation/verified.ex`)
runs the engine's `verify` op on the attribute:

```elixir
create :keep do
  accept [:name, :receipt]
  validate {AshAffidavit.Validation.Verified, attribute: :receipt}
end
```

A `nil` attribute passes (add `allow_nil?: false` to require a receipt).
A rejected receipt or any refused/trapped call fails the validation.

## 5. Read a per-record verdict

`AshAffidavit.Calculation.Verdict` (`lib/ash_affidavit/calculation/verdict.ex`)
returns `:accept`, `:reject`, `:refused`, `:trap`, `:unsupported`, or
`nil` for a nil attribute:

```elixir
calculations do
  calculate :verdict, :atom, {AshAffidavit.Calculation.Verdict, attribute: :receipt}
end
```

## 6. Observe completed actions

`AshAffidavit.Notifier` (`lib/ash_affidavit/notifier.ex`) emits
`[:ash_affidavit, :notifier, :action]` (`%{count: 1}`, metadata
`%{resource, action, evidence}`) after any action whose changeset carries
evidence under the default `:affidavit` context key:

```elixir
use Ash.Resource,
  domain: MyApp.Domain,
  simple_notifiers: [AshAffidavit.Notifier],
  extensions: [AshAffidavit.Resource]
```

## 7. Troubleshooting

- `unknown_operation` compile error: the op is not in `AshAffidavit.ops/0`.
- `singleton_without_server`: you set `singleton false` without a
  `runtime do server ... end`.
- Every call refuses with `host_not_started`: the pool is not running —
  set `start_pool: true` or pass `server:`.
- `Ash.bulk_update/4` with `strategy: :atomic` is refused: the change
  requires a WASM call; use `strategy: :stream`.

## See Also

`docs/diataxis/reference/public-api.md` ·
`docs/diataxis/explanation/outcomes-authority-and-refusals.md`
