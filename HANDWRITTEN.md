# HANDWRITTEN

Ledger of every hand-written element that no pack capability emits, and of generator gaps worked
around in the contract. Each hand-written source file carries the header
`# UNSUPPORTED(generator-capability): <reason>`. Generated files are never hand-edited; change
`ontology/affidavit-binding.ttl` or `ontology/affidavit-contract.ttl` and run `scripts/consume.sh`
(pack and artifact pins in `consumer-pack.pin`).

## Generated (qri-consumer-binding-pack, profile beam-wasmex)

`lib/ash_affidavit/abi.ex`, `wasm_config.ex`, `engine_load.ex`, `host.ex`, `pool.ex`,
`lib/mix/tasks/ash_affidavit.vendor.ex`, `lib/mix/tasks/ash_affidavit.verify.ex`,
`priv/affidavit/MANIFEST.json`.

## Hand-written residue

| path | reason |
|---|---|
| `lib/ash_affidavit/refusal.ex` | no pack template emits a per-contract refusal module; the generated host aliases `qri:refusalModule` and calls `Refusal.new/3` with 17 host codes the contract does not declare; the flat engine error-code mapping (class and outcome policy) is hand policy |
| `lib/ash_affidavit.ex` | no pack template emits a public API over the host (op registry from the capability registry, ok/refused/trap/unsupported mapping, flat-code envelope decoding) |
| `lib/ash_affidavit/application.ex` | no pack template emits an OTP application callback |
| `priv/affidavit/capability-registry.json`, `op-examples.json` | copied from the engine repository's `registry/` (generated there by wasi-json-abi-pack); not generated here |

## Generator gaps recorded as UNSUPPORTED(generator-capability)

| gap | worked around by |
|---|---|
| `host.ex.tmpl` fails to render (`Variable init_export not found`) when the contract declares no optional export; the affidavit module exports no `_initialize` | the contract declares `qri:optionalExport "_initialize"`; the generated host only calls it when the module exports it, so behaviour is unchanged |
| `qri:errorCollapse "flat_code"` passes gate 080 but no template consumes it; the generated host returns `{:ok, map}` for both `"ok" => true/false` bodies | hand-written `AshAffidavit.call/2` and `Refusal.from_engine/1` decode the flat `{"ok":false,"error":{"code":...}}` envelope |
| no template emits or checks the host refusal code table the templates depend on | hand-written `AshAffidavit.Refusal`, with a compile-time check that every registry error code is classified |
| `af_abi_version` is enforced as a required export but no template calls it; the verify task probes the `capabilities` op's `abi_version` key | a test calls `af_abi_version` through wasmex and compares it to the manifest |
| `qri:wasiImport`/`qri:allowedImport` rows are gate-checked against each other (gate 070) but never projected into the manifest or compared with the real module's import section | a test compares contract, manifest and real module imports |
| no deps fragment is emitted (`jason`, `wasmex`, `telemetry` are required by the generated code) | declared by hand in `mix.exs` |
| generated files carry no SPDX header | `REUSE.toml` annotation |

## Not built (future work)

An Ash extension point (DSL section, change, validation) is not shipped; `ash` and `spark` are
declared dependencies for it. No pack in the beam-host set emits one, and it would be hand-written.

## See Also

`ontology/affidavit-binding.ttl`, `ontology/affidavit-contract.ttl`, `scripts/consume.sh`,
`consumer-pack.pin`
