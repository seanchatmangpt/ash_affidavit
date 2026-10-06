# HANDWRITTEN

Ledger of every hand-written element that no pack capability emits, and of generator gaps worked
around. Each hand-written source file carries the header
`# UNSUPPORTED(generator-capability): <reason>`. A module has exactly one authority: a projection
from RDF or a ledgered residue, never both (`test/ash_affidavit_extension_render_test.exs` checks it).
Generated files are never hand-edited: repair the ontology, profile, generator or template and regenerate.

## Generated

### qri-consumer-binding-pack, profile beam-wasmex

Source: `ontology/affidavit-binding.ttl` + `ontology/affidavit-contract.ttl`. Command: `scripts/consume.sh`
(pins and per-file digests in `consumer-pack.pin`; refuses a pack export whose fingerprint is not
`pack_fingerprint`).

`lib/ash_affidavit/abi.ex`, `wasm_config.ex`, `engine_load.ex`, `host.ex`, `pool.ex`,
`lib/mix/tasks/ash_affidavit.vendor.ex`, `lib/mix/tasks/ash_affidavit.verify.ex`,
`priv/affidavit/MANIFEST.json`.

### ash-extension-pack 0.3.0 (Spark extension)

Source: `ontology/affidavit-extension.ttl` (`aex:` individuals). Command: `scripts/render_extension.sh`
(`ggen.toml`; pack pinned by `ext_pack_*` in `consumer-pack.pin`, refused on a content-digest mismatch;
`--check` proves two byte-identical renders equal to the tree). The pack is read from an export and never
written to; ggen runs in a scratch capsule.

`lib/ash_affidavit/resource.ex` (extension, `Dsl.Runtime` and `Dsl.Operation` structs), `persist.ex`,
`verify.ex`, `info.ex`, `test/ash_affidavit_composition_test.exs`.

Observed limits of the projection, kept as recorded divergences:

- The pack emits no per-entity `describe`, no moduledoc beyond boilerplate (it names `ash-extension-core-pack`,
  a superseded pack), and the verifier carries no DSL `path` or `module`: the legality text embeds the path
  in the message instead (`AshAffidavit.Resource.Validate`).
- The `name` field of `operation` is type `any` (the pack's closed type set has no atom-or-string union); the
  verifier refuses anything that is not an engine op.
- Info getters read a persisted section key, not the normalized `runtime`/`operations` split, so no
  `aex:InfoGetter` is declared and `AshAffidavit.Resource.Declared` carries them.
- The pack output is unformatted; `scripts/render_extension.sh` runs `mix format` twice (one pass is not a fixed point).

## Hand-written residue

| path | reason |
|---|---|
| `lib/ash_affidavit/refusal.ex` | no pack template emits a per-contract refusal module; the generated host aliases `qri:refusalModule` and calls `Refusal.new/3` with host codes the contract does not declare; the flat engine error-code mapping and the class and outcome policy are hand policy. `authority_escalation` (class `refused_authority`) is the code for a response that states an authority above NONE |
| `lib/ash_affidavit.ex` | no pack template emits a public API over the host (op registry from the capability registry, ok/refused/trap/unsupported mapping, flat-code envelope decoding, non-object request refusal, authority NONE guard `authority_none?/1`) |
| `lib/ash_affidavit/application.ex` | no pack template emits an OTP application callback |
| `priv/affidavit/capability-registry.json`, `op-examples.json` | copied from the engine repository's `registry/` (generated there by wasi-json-abi-pack); not generated here |
| `lib/ash_affidavit/resource/normalize.ex` | `aex:normalizeModule` target: the pack pipes the raw section entities through it but emits no body |
| `lib/ash_affidavit/resource/validate.ex` | `aex:validateDelegateModule` target: the pack emits the verifier shell, not the checks (registry membership, ceiling, timeout, trusted keys, singleton) |
| `lib/ash_affidavit/resource/declared.ex` | `runtime/1` and `operations/1` over the normalized declaration (see the Info limit above) |
| `lib/ash_affidavit/formatter.ex` | no pack template emits a formatter plugin; the installer registers it and `.formatter.exs` exports `locals_without_parens` |
| `lib/ash_affidavit/change/receipt.ex`, `lib/ash_affidavit/validation/verified.ex`, `lib/ash_affidavit/calculation/verdict.ex`, `lib/ash_affidavit/notifier.ex` | no pack template emits Ash change, validation, calculation or notifier modules |
| `lib/ash_affidavit/type/receipt.ex`, `lib/ash_affidavit/type/chain_hash.ex` | no pack template emits Ash types |
| `lib/ash_affidavit/error/refused.ex` | no pack template emits a Splode error; it wraps `AshAffidavit.Refusal`, which stays unchanged because the generated host aliases it |
| `lib/ash_affidavit/reactor/step.ex` | the pack's `reactor_step.ex.tmpl` emits an arguments-echo stub, not a step that calls the engine, and `aex:workflowReactor` is false; the generic step is guarded by `Code.ensure_loaded?(Reactor.Step)`. Not built: a Reactor DSL entity (`affidavit_op`), a telemetry middleware, a generated pipeline |
| `lib/ash_affidavit/signing.ex` | no pack template emits a signature-envelope surface over the engine's
`verify_signature_input` op (host gates on the 12-field `CTP-ENVELOPE-v1` closure, caller-attested subject
binding, pre-image binding through the real wasm call; AG2 lane). The pinned wasm ABI has no cryptographic
signature-verify op and no subject-digest derivation op — `verified_pre_image` is an engine witness,
`subject_binding` a host witness, never a signature verdict |
| `lib/ash_affidavit/signing/keys.ex` | no pack template emits a key/JWKS loading surface; structural
normalization and closed algorithm-set routing only (the wasm ABI consumes no key material) |
| `lib/ash_affidavit/ops.ex` | no pack template emits typed wrappers over the remaining wasm-ABI ops
(`assemble`, `mine`, `conform`, `certify_authzen_evidence`, `certify_spiffe_evidence`, `jcs_canonicalize`,
`smt_absence_verify`, `range_proof_verify`); one typed function plus a pure request-map builder per op,
mirroring the `verify_signature` pattern; courts assert the built requests against
`priv/affidavit/op-examples.json` (EA60 lane) |
| `test/support/affidavit_resource.ex` | test fixture resource and domain; no pack template emits Ash fixtures |
| `.formatter.exs`, `.credo.exs`, `mix.exs` | repo configuration; no pack emits project config or the Spark formatter export list; `mix.exs` also holds the hand-declared deps (see gaps) |
| `scripts/consume.sh`, `scripts/render_extension.sh`, `scripts/pack_fingerprint.py`, `ggen.toml` | consumer-side drivers; no pack emits them |

Not built (no file exists): `mix ash_affidavit.upgrade` (Igniter upgrade tasks), a domain-level extension, a
Reactor DSL extension. They are absent, not stubbed.

## Generator gaps recorded as UNSUPPORTED(generator-capability)

| gap | worked around by |
|---|---|
| `host.ex.tmpl` fails to render (`Variable init_export not found`) when the contract declares no optional export; the affidavit module exports no `_initialize` | the contract declares `qri:optionalExport "_initialize"`; the generated host only calls it when the module exports it, so behaviour is unchanged; the template is fixed upstream (marketplace 80d429f), the declaration is kept so the host stays byte-identical to the pinned contract |
| `qri:errorCollapse "flat_code"` passes gate 080 but no template consumes it; the generated host returns `{:ok, map}` for both `"ok" => true/false` bodies | hand-written `AshAffidavit.call/2` and `Refusal.from_engine/1` decode the flat `{"ok":false,"error":{"code":...}}` envelope |
| no template emits or checks the host refusal code table the templates depend on | hand-written `AshAffidavit.Refusal`, with a compile-time check that every registry error code is classified |
| `af_abi_version` is enforced as a required export but no template calls it; the verify task probes the `capabilities` op's `abi_version` key | a test calls `af_abi_version` through wasmex and compares it to the manifest |
| `qri:wasiImport`/`qri:allowedImport` rows are gate-checked against each other (gate 070) but never projected into the manifest or compared with the real module's import section | a test compares contract, manifest and real module imports |
| no deps fragment is emitted (`jason`, `wasmex`, `telemetry` are required by the generated code) | declared by hand in `mix.exs` |
| generated files carry no SPDX header | `REUSE.toml` annotation |
| retired: the ash-extension-pack installer `--target` defect (bare `extensions: [...]` given to `Igniter.Code.Common.add_code/3`) | fixed upstream (`Spark.Igniter.add_extension/5`, marketplace 80d429f); `scripts/patches/` and the patch step of `scripts/render_extension.sh` are removed after `test/ash_affidavit_install_test.exs` (incl. the second-run no-diff test) passed on the unpatched pack output; `lib/mix/tasks/ash_affidavit.install.ex` is now generated |

## See Also

`ontology/affidavit-binding.ttl`, `ontology/affidavit-contract.ttl`, `ontology/affidavit-extension.ttl`,
`scripts/consume.sh`, `scripts/render_extension.sh`, `consumer-pack.pin`
