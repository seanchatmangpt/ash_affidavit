# ash_affidavit migration plan v26.11.16

Standing: UNVERIFIED

## Identity
- Path: /Users/sac/ash_affidavit
- Remote: https://github.com/seanchatmangpt/ash_affidavit.git (upstream origin/main)
- Branch: main@ffc8dfd; last commit 2026-11-07; 38 commits; 258 MB
- Languages/build: Elixir/Ash (mix.exs, mix.lock), Rust->wasm32-wasip1 engine via wasmex,
  ggen.toml, REUSE.toml. No CLAUDE.md (AGENTS.md present).
- Nested repos: none

## Observed state
- Dirty 21 / untracked 30. ahead 0 / behind 0, stash 0, unpushed branches 0.
- Modified: .gitignore, CHANGELOG.md, HANDWRITTEN.md, README.md, mix.exs,
  lib/ash_affidavit/{chain_verifier,signing,signing/keys}.ex,
  test/ash_affidavit_signing_courts_test.exs, docs/diataxis/** (several), documentation/**,
  usage-rules/setup.md. Deleted: docs/diataxis/reference/generated/*.md (4 files).
- Untracked: docs/diataxis/reference/descriptors/, docs/jira/, docs/sjira/v26.11.10/,
  test/ash_affidavit_chain_verifier_test.exs (new test for the Ed25519 verifier commit).
- Build/dep dirs: _build-ev14b/ 101 MB (non-standard name, ignored?); no _build/ or deps/.
  ash_affidavit-26.10.1.tar 160 KB (hex package tarball) at root; tmp/ empty.
- Other branches: feat/signing-surface, manufacture/v26.9.30-consumer-binding (both tracked).
- Submodules: none.

## What it is
Elixir/Ash package wrapping the affidavit WASM engine (Rust compiled to wasm32-wasip1 run on
the BEAM through wasmex): builds and checks receipts over operation events, mines process
models, checks signing inputs. Published on hex.pm.

## Classification
ACTIVE (census agrees; commits within the last 10 days, in-flight signing/verifier work).

## Migration risk
HIGH. Uncommitted source changes in lib/ash_affidavit/signing*, chain_verifier.ex, mix.exs
and a new untracked test file would be lost. Docs campaign work (docs/sjira/v26.11.10/,
descriptors/) is untracked. No stashes, nothing unpushed, remote is real. No .env/db found.

## Recommended action
COMMIT-PUSH
1. `cd /Users/sac/ash_affidavit && git status` — review the 21 M/D and 30 ?? paths.
2. DECISION: keep or drop the 4 deleted docs/diataxis/reference/generated/*.md files.
3. `git add -A && git commit -m "wip(v26.11.16): signing/chain_verifier + docs campaign"`
4. `git push origin main`
5. `rm -rf _build-ev14b` (101 MB) and `rm -f ash_affidavit-26.10.1.tar` (re-fetchable
   from hex). DECISION: is _build-ev14b a deliberate build lane to keep?
6. On new machine: `git clone https://github.com/seanchatmangpt/ash_affidavit.git`.

## First commands on the new machine
`mix deps.get && mix compile --warnings-as-errors && mix test` (needs Erlang/Elixir per
.tool-versions and a Rust toolchain with the wasm32-wasip1 target).

## See Also
- ../v26.11.12/
- /Users/sac/docs/jira/v26.11.16/README.md
