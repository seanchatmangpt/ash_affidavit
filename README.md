# ash_affidavit

Elixir/Ash package around the affidavit WASM engine (Rust compiled to `wasm32-wasip1`, executed on
the BEAM through [wasmex](https://hex.pm/packages/wasmex)). The engine builds and checks receipts over
operation events, mines process models from them and checks signing inputs.

This package grants no execution authority. A response is the engine's computation over exactly the
request you sent; it is not an authorization, not a DO receipt, and not a standing.

## Install

```elixir
def deps do
  [{:ash_affidavit, "~> 26.9.30"}]
end
```

The engine is vendored in `priv/affidavit/affidavit.wasm`. Its SHA-256 pin lives in
`priv/affidavit/MANIFEST.json`; `mix ash_affidavit.vendor --check` and `mix ash_affidavit.verify`
re-check it without network access. The `artifact.url` in the manifest is the intended release
location and is a placeholder: it was not published or fetched; the vendored file is the source.

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
from `ontology/affidavit-contract.ttl` by the qri-qualification-profile-pack beam-host projection
(`scripts/render_host.sh`). Change the contract, not those files. The hand-written residue and why
it is hand-written is listed in `HANDWRITTEN.md`.

## Not included

An Ash resource extension (DSL section, change, validation) is future work; the package depends on
`ash` and `spark` for that extension point but ships none yet.

## See Also

`HANDWRITTEN.md`, `CHANGELOG.md`, `ontology/affidavit-contract.ttl`
