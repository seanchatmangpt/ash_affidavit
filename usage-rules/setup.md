<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# Setting up AshAffidavit

- Install with `mix igniter.install ash_affidavit` when Igniter is available. Otherwise add
  `{:ash_affidavit, "~> 26.10.1"}` and `{:wasmex, "~> 0.15.1"}` to `deps`, and
  `import_deps: [:ash_affidavit]` to `.formatter.exs`.
- The engine is vendored at `priv/affidavit/affidavit.wasm` and pinned by SHA-256 in
  `priv/affidavit/MANIFEST.json`. Run `mix ash_affidavit.vendor --check` to compare the file with the
  pin and `mix ash_affidavit.verify` to admit the engine (digest, import surface, exports).
- Start a pool with `config :ash_affidavit, start_pool: true, pool: [size: 2]`, or supervise
  `AshAffidavit.Pool` or `AshAffidavit.Host` yourself and pass `server:` to `AshAffidavit.call/2`.
- Do not disable the digest pin to make a call work. A `:wasm_digest_mismatch` refusal means the bytes
  are not the pinned engine.
