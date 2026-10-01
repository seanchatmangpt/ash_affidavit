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

Never hand-edit these; regenerate from the ontology with `scripts/consume.sh`:

- `lib/ash_affidavit/{abi,wasm_config,engine_load,host,pool}.ex`
- `lib/mix/tasks/ash_affidavit.{vendor,verify}.ex`
- `priv/affidavit/MANIFEST.json`

Hand-written files carry `# UNSUPPORTED(generator-capability): <reason>` and a row in `HANDWRITTEN.md`.

## Pinned and owned elsewhere

`consumer-pack.pin` and `ontology/affidavit-binding.ttl` are off-limits unless the task is to
regenerate the host. A test compares the generated files with the digests in `consumer-pack.pin`.

## Test ladder

Cheapest first, with `MIX_BUILD_ROOT` set:

1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict`
4. `mix test` (real pinned wasm, no mocks)
5. `mix docs --warnings-as-errors`
6. `mix hex.build --unpack`

Do not run `mix hex.publish` from an agent session: publishing needs the maintainer's Hex API key.
