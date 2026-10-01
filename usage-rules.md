<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# Rules for working with AshAffidavit

AshAffidavit runs the affidavit WASM engine on the BEAM and exposes it to Ash. Follow these rules.

## Understanding AshAffidavit

- AshAffidavit grants no authority. `{:ok, response}` is the engine's computation over the exact
  request given. It is not an authorization, a DO receipt or a standing.
- Call the engine only through `AshAffidavit.call/2`. Do not call `AshAffidavit.Host` or the wasmex
  instance directly from application code.
- Every outcome is typed: `{:ok, map}`, `{:refused, %AshAffidavit.Refusal{}}`,
  `{:trap, %AshAffidavit.Refusal{}}`, `{:unsupported, %AshAffidavit.Refusal{}}`. Match all four. Never
  collapse them into one error branch.
- Declare the engine operations a resource uses with `extensions: [AshAffidavit.Resource]` and an
  `affidavit` section. Read the declaration with `AshAffidavit.Resource.Info`.
- Use `AshAffidavit.Change.Receipt` to run an op inside an action. Its evidence lands in
  `changeset.context` (default key `:affidavit`); a non-ok outcome adds an
  `AshAffidavit.Error.Refused` to the changeset.
- Never edit generated files: `lib/ash_affidavit/{abi,wasm_config,engine_load,host,pool}.ex`,
  `lib/mix/tasks/ash_affidavit.{vendor,verify}.ex`, `priv/affidavit/MANIFEST.json`. Change
  `ontology/affidavit-binding.ttl` or `ontology/affidavit-contract.ttl` and regenerate with
  `scripts/consume.sh`.

## Sub-rules

- [Setup](usage-rules/setup.md): vendor and verify tasks, pool configuration
- [Outcomes](usage-rules/outcomes.md): the four-way outcome mapping
- [Testing](usage-rules/testing.md): Chicago-style tests against the real wasm
