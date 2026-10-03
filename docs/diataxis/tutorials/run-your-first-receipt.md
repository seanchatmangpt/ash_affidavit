# Run Your First Receipt

Build, verify and mine over an affidavit receipt with the vendored WASM engine —
no Ash resource, no signing keys, no network.

In this tutorial you will:

- start the engine pool,
- commit a payload and receive a commitment,
- assemble events into a receipt,
- verify the receipt,
- mine a process model from receipts.

Everything runs locally: the engine is vendored at
`priv/affidavit/affidavit.wasm` and pinned by
`priv/affidavit/MANIFEST.json` (affidavit v26.9.28, ABI 1).

## Before you start

- Elixir on the BEAM with the `ash_affidavit` dependency installed
  (`{:ash_affidavit, "~> 26.10.1"}`).
- No extra services. The engine runs in-process via `wasmex`.

## 1. Start the pool

Put this in `config/config.exs`:

```elixir
config :ash_affidavit, start_pool: true, pool: [size: 2]
```

`AshAffidavit.Application` then starts `AshAffidavit.Pool` under the
application supervisor. Without `start_pool: true` you must start
`AshAffidavit.Pool` or `AshAffidavit.Host` yourself and pass
`server: pid_or_name` to every call (see
`lib/ash_affidavit/pool.ex`, `lib/ash_affidavit/host.ex`).

## 2. List what the engine can do

`AshAffidavit.ops/0` reads the engine's own capability registry
(`lib/ash_affidavit.ex:94`):

```elixir
AshAffidavit.ops()
#=> ["capabilities", "commit", "assemble", "verify", "mine", "conform",
#    "verify_signature_input", "certify_authzen_evidence", "certify_spiffe_evidence"]
```

`AshAffidavit.capabilities/1` runs the `capabilities` op and returns the
engine's answer:

```elixir
{:ok, caps} = AshAffidavit.capabilities()
```

## 3. Commit a payload

`commit` takes a payload and returns a `commitment` (a payload commitment
hash):

```elixir
{:ok, %{"commitment" => commitment}} =
  AshAffidavit.call(%{"op" => "commit", "payload" => "hello"})
```

## 4. Assemble events into a receipt

`assemble` takes events (each with `event_type`, `objects`, `payload`) and
returns a receipt with a `chain_hash` and sequenced events:

```elixir
{:ok, assembled} =
  AshAffidavit.call(%{
    "op" => "assemble",
    "events" => [
      %{"event_type" => "build", "objects" => ["repo:git:main"], "payload" => "compile step\n"},
      %{"event_type" => "test", "objects" => ["suite:test-suite:unit"], "payload" => "unit tests\n"},
      %{"event_type" => "deploy", "objects" => ["svc:service"], "payload" => "ship it\n"}
    ]
  })

receipt = assembled["receipt"]
#=> %{"chain_hash" => "d6cd...", "events" => [...], "format_version" => "core/v1"}
```

The exact request/response shapes above are the engine's own examples,
read from `priv/affidavit/op-examples.json`.

## 5. Verify the receipt

```elixir
{:ok, %{"accepted" => true}} =
  AshAffidavit.call(%{"op" => "verify", "receipt" => receipt})
```

If you tamper with the receipt the engine answers `"ok" => false` with an
error envelope, and `AshAffidavit.call/2` maps it to
`{:refused, %AshAffidavit.Refusal{}}` (see
`lib/ash_affidavit.ex:145`).

## 6. Mine a process model

`mine` takes a list of receipts and returns a mined process model.

```elixir
{:ok, model} = AshAffidavit.call(%{"op" => "mine", "receipts" => [receipt]})
```

`conform` checks receipts against a mined model.

## 7. Where next

- Attach receipts to Ash resources: see
  `docs/diataxis/how-to/use-the-ash-extension.md`.
- The full module and function list: see
  `docs/diataxis/reference/public-api.md`.
- Why outcomes and authority are kept separate: see
  `docs/diataxis/explanation/outcomes-authority-and-refusals.md`.
