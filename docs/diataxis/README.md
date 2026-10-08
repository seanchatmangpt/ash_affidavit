# Documentation Map (Diataxis)

The guides under `docs/diataxis/` follow the
[Diataxis](https://diataxis.fr/) framework. Pages are also published in the
`AshAffidavit` hex docs (see `mix.exs`, `docs/0` `extras`): tutorials and
how-to pages under GUIDES, the reference under the module lists.

Every entry verified against `lib/` in ash_affidavit 26.10.8.

## Tutorials

- [Run Your First Receipt](tutorials/run-your-first-receipt.md) — build,
  verify and mine over an affidavit receipt with the vendored WASM engine; no
  Ash resource, no signing keys, no network.

## How-to guides

- [Attach Engine Receipts to Ash Resources](how-to/use-the-ash-extension.md) —
  record an engine affidavit alongside your records, validate receipts on
  write, expose a per-record verdict.
- [Verify a Signature Envelope](how-to/signature-envelope.md) — load key
  material from a JWKS, adjudicate a signature and bind a subject through the
  engine's signing ops.

## Reference

- [Public API](reference/public-api.md) — every public function, the engine
  ops, host/pool, refusals, configuration and mix tasks.

## Explanation

- [Outcomes, Authority and Refusals](explanation/outcomes-authority-and-refusals.md) —
  why the surface returns typed outcomes instead of raising, and why declared
  authority is always NONE.
