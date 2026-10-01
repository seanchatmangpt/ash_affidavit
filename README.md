# ash_affidavit

[![CI](https://github.com/seanchatmangpt/ash_affidavit/actions/workflows/ci.yml/badge.svg)](https://github.com/seanchatmangpt/ash_affidavit/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/ash_affidavit.svg)](https://hex.pm/packages/ash_affidavit)
[![Hexdocs](https://img.shields.io/badge/hexdocs-ash__affidavit-blue.svg)](https://hexdocs.pm/ash_affidavit)
[![REUSE status](https://api.reuse.software/badge/github.com/seanchatmangpt/ash_affidavit)](https://api.reuse.software/info/github.com/seanchatmangpt/ash_affidavit)

Elixir/Ash package around the affidavit WASM engine (Rust compiled to `wasm32-wasip1`, executed on
the BEAM through [wasmex](https://hex.pm/packages/wasmex)). The engine builds and checks receipts over
operation events, mines process models from them and checks signing inputs.

This package grants no execution authority. A response is the engine's computation over exactly the
request you sent; it is not an authorization, not a DO receipt, and not a standing.

## Install

With [Igniter](https://hex.pm/packages/igniter):

```sh
mix igniter.install ash_affidavit
```

Manual steps: add the dependencies, then add `import_deps: [:ash_affidavit]` to `.formatter.exs`.

```elixir
def deps do
  [
    {:ash_affidavit, "~> 26.9.30"},
    {:wasmex, "~> 0.15.1"}
  ]
end
```

The engine is vendored in `priv/affidavit/affidavit.wasm`. Its SHA-256 pin lives in
`priv/affidavit/MANIFEST.json`; `mix ash_affidavit.vendor --check` and `mix ash_affidavit.verify`
re-check it without network access. The `artifact.url` in the manifest is the published release asset
(affidavit v26.9.28); the vendored file is the source and needs no network.

## Use

```elixir
# config/config.exs
config :ash_affidavit, start_pool: true, pool: [size: 2]

{:ok, %{"commitment" => c}} = AshAffidavit.call(%{"op" => "commit", "payload" => "hello"})

{:ok, assembled} =
  AshAffidavit.call(%{
    "op" => "assemble",
    "events" => [%{"event_type" => "build", "objects" => ["repo:git:main"], "payload" => "ok"}]
  })

{:ok, %{"accepted" => true}} = AshAffidavit.call(%{"op" => "verify", "receipt" => assembled["receipt"]})

AshAffidavit.ops()
#=> ["capabilities", "commit", "assemble", "verify", "mine", "conform", "verify_signature_input", "certify_authzen_evidence", "certify_spiffe_evidence"]
```

Without `start_pool: true`, start `AshAffidavit.Pool` yourself, or `AshAffidavit.Host`, and pass
`server: pid_or_name` to `call/2`.

## Outcomes

`call/2` keeps four outcomes distinct:

| result | meaning |
|---|---|
| `{:ok, map}` | engine answered `"ok" => true` |
| `{:refused, %AshAffidavit.Refusal{}}` | bad input (`bad_field`, `missing_field`, `too_deep`, ...), or host refusal (digest pin, import surface, oversize request, saturation) |
| `{:trap, %AshAffidavit.Refusal{}}` | engine or host failed at run time; the host recycles the instance |
| `{:unsupported, %AshAffidavit.Refusal{}}` | unknown op, or an engine error code this library does not know |

## Engine admission

Before any instance exists the engine bytes are judged in this order: SHA-256 against the manifest
pin, compile, import surface (exactly `environ_get`, `environ_sizes_get`, `fd_write`, `proc_exit`
from `wasi_snapshot_preview1`), required exports (`af_alloc`, `af_call`, `af_free`,
`af_abi_version`, `memory`). Requests are capped at 16 MiB.

## Provenance of the host code

`lib/ash_affidavit/{abi,wasm_config,engine_load,host,pool}.ex` and the two Mix tasks are generated
from `ontology/affidavit-binding.ttl` and `ontology/affidavit-contract.ttl` by the
qri-consumer-binding-pack (`scripts/consume.sh`, pins in `consumer-pack.pin`). Change the binding or
contract, not those files. The hand-written residue and why
it is hand-written is listed in `HANDWRITTEN.md`.

## Ash extension

```elixir
defmodule MyApp.Build do
  use Ash.Resource, domain: MyApp.Domain, extensions: [AshAffidavit.Resource]

  affidavit do
    runtime do
      timeout_ms 2_000
    end

    operation :commit
  end

  actions do
    create :record do
      accept [:name]
      change {AshAffidavit.Change.Receipt, op: :commit, request: &__MODULE__.commit_request/1}
    end
  end

  def commit_request(changeset), do: %{"payload" => Ash.Changeset.get_attribute(changeset, :name)}
end
```

The engine response is stored at `changeset.context[:affidavit]`. Any refused, trapped or
unsupported outcome fails the action with an `AshAffidavit.Error.Refused` that keeps the typed
`AshAffidavit.Refusal`. Also shipped: `AshAffidavit.Validation.Verified`,
`AshAffidavit.Calculation.Verdict`, `AshAffidavit.Type.Receipt`, `AshAffidavit.Type.ChainHash`,
`AshAffidavit.Notifier`. See `documentation/` and `usage-rules.md`.

## Configuration

Read by `AshAffidavit.WasmConfig`:

| key | meaning |
|---|---|
| env `AFFIDAVIT_WASM_PATH`, or `config :ash_affidavit, :wasm_path` | engine path; default is the vendored file (the digest pin applies to the vendored path) |
| `config :ash_affidavit, start_pool: true, pool: [size: n]` | start `AshAffidavit.Pool` under the application supervisor |
| `config :ash_affidavit, <limit>: pos_integer` | resource limits: `timeout_ms` (5000), `max_queue` (64), `memory_limit_bytes`, `recycle_bytes`, `max_response_bytes`, `fuel`, `fuel_per_ms`, `instantiate_fuel`, `table_elements`, `instances`, `tables`, `memories` |

## See Also

`HANDWRITTEN.md`, `CHANGELOG.md`, `ontology/affidavit-contract.ttl`
