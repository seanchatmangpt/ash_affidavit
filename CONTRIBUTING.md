<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# Contributing

- Read `AGENTS.md` for the build root, the generated-file fence and the test ladder.
- Generated files are not edited by hand: change `ontology/affidavit-binding.ttl` or
  `ontology/affidavit-contract.ttl` and run `scripts/consume.sh`.
- New hand-written files carry `# UNSUPPORTED(generator-capability): <reason>` and an SPDX header, and
  get a row in `HANDWRITTEN.md`.
- Tests use real collaborators (the pinned wasm, an ETS-backed Ash resource). Mocks are not accepted.
- Run `mix format`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix test` and
  `mix docs --warnings-as-errors` before opening a pull request.
- Commit messages follow conventional commits (`feat:`, `fix:`, `docs:`).
