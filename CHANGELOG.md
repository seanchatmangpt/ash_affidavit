# CHANGELOG

## 26.9.30

Initial release.

- `AshAffidavit.call/2`, `capabilities/1`, `abi_version/0`, `ops/0`, `registry/0` over the affidavit
  WASM engine (ABI 1, seven ops: `capabilities`, `commit`, `assemble`, `verify`, `mine`, `conform`,
  `verify_signature_input`).
- Vendored engine `priv/affidavit/affidavit.wasm` (264736 bytes, sha256
  `1be9678b2ddcaf71a5c18926ffb94ee4fba9963877e3f4be081eef1d6f42f436`), pinned in
  `priv/affidavit/MANIFEST.json`; admission refuses a digest mismatch before compile, an import
  outside the four WASI imports the module declares, and a missing required export.
- `AshAffidavit.Refusal`: closed typed code set (host codes plus the engine's flat error codes read
  from the capability registry) with three distinct outcomes: `:refused`, `:trap`, `:unsupported`.
- Host files (`ABI`, `WasmConfig`, `EngineLoad`, `Host`, `Pool`, `mix ash_affidavit.vendor`,
  `mix ash_affidavit.verify`) are generated from `ontology/affidavit-contract.ttl` by the
  qri-qualification-profile-pack beam-host projection (`scripts/render_host.sh`).
- No execution authority is granted by this package.
