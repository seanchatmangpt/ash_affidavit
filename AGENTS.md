<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# AGENTS

Guidance for coding agents working in this checkout. See `usage-rules.md` for rules about using the
library itself.

## Build isolation

Use a private build root for every mix command so concurrent sessions do not collide:

```sh
MIX_BUILD_ROOT=_build-lane-<name> mix test
```

`/_build-lane-*/` is git-ignored.

## Generated files (fence)

Never hand-edit these; repair the ontology and regenerate.

From `ontology/affidavit-{binding,contract}.ttl` with `scripts/consume.sh`:

- `lib/ash_affidavit/{abi,wasm_config,engine_load,host,pool}.ex`
- `lib/mix/tasks/ash_affidavit.{vendor,verify}.ex`
- `priv/affidavit/MANIFEST.json`

From `ontology/affidavit-extension.ttl` with `scripts/render_extension.sh` (`--check` proves it):

- `lib/ash_affidavit/{resource,persist,verify,info}.ex`, `lib/mix/tasks/ash_affidavit.install.ex`,
  `test/ash_affidavit_composition_test.exs`

Hand-written files carry `# UNSUPPORTED(generator-capability): <reason>` and a row in `HANDWRITTEN.md`.

## Pinned and owned elsewhere

`consumer-pack.pin` and `ontology/affidavit-binding.ttl` are off-limits unless the task is to
regenerate the host. A test compares the generated files with the digests in `consumer-pack.pin`. With
`ASH_AFFIDAVIT_PACK_ROOT` set, a court also fails closed on a stale `pack_fingerprint`; with
`ASH_AFFIDAVIT_EXT_PACK_ROOT` set, `render_extension.sh --check` runs.

## Test ladder

Cheapest first, with `MIX_BUILD_ROOT` set:

1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict` (and `MIX_ENV=test mix dialyzer`, `MIX_ENV=test mix sobelow --skip`)
4. `mix test` (real pinned wasm, no mocks)
5. `mix docs --warnings-as-errors`
6. `mix hex.build --unpack`

Do not run `mix hex.publish` from an agent session: publishing needs the maintainer's Hex API key.
