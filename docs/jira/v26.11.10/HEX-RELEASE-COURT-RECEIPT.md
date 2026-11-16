# Receipt: Hex Release Court (`@teamwork-m1` / `hex-release-court`)

- **Slice**: `hex-release-court`
- **Milestone**: `v26.11.10`
- **Date**: `2026-11-10`
- **Base Git HEAD**: `ffc8dfd4a98946079ced44c530dc4a8e38ad491f` (`main`, working tree CalVer synchronized & formatted)
- **Hex Package**: `ash_affidavit` `26.11.10`
- **Court Standing**: `PARTIAL_ALIVE` (Hex package build, checksums, unpack closure, test ladder rungs 1-6, and `mix hex.publish --dry-run --yes` all green with exit 0; `ALIVE` requires green CI against the committed release SHA plus maintainer Hex key publication per `AGENTS.md`)

---

## 1. Hex Tarball & Cryptographic Checksums (`O*`)

| Artifact / Field | Observed Value |
|---|---|
| Tarball Path | `_build-lane-m1/ash_affidavit-26.11.10.tar` |
| Tarball Format Version | `3` (`VERSION`) |
| Tarball Byte Size | `317,952` bytes (`310.5 KB`) |
| **Package / Outer SHA-256** (`mix hex.build` & `shasum -a 256`) | `ae0acc06e4a184e318e32c18a4f3de0f7e6bd28e40e492daabf8ea63b947f6ee` |
| **Inner Hex `CHECKSUM`** (`SHA256(VERSION \|\| metadata.config \|\| contents.tar.gz)`) | `3F8F5A5098AB2F81AD8093E1D53F0A77F8A207D13ABD1F285785FEF6C3B54595` |
| Packaged Entry Count (`contents.tar.gz`) | `61` files (`0` directory entries, `0` forbidden path leaks) |
| Wasm Engine SHA-256 (`priv/affidavit/affidavit.wasm`) | `5cc37aea8e59f7139e2ff5d43ab3c3c82931285b6400cf45f943c61d21a41402` |
| Wasm ABI Version | `1` |

### Boundary Exclusion & Package Closure Audit (`0` leaks)
Verified `contents.tar.gz` and `_build-lane-m1/pkg_unpack` contain **zero** forbidden entries matching:
- `_build*` (all lanes excluded)
- `cover/`
- `tmp/`
- `test/`
- `docs/jira/`, `docs/sjira/`
- `priv/courts/`

Mandatory closure files present in package root:
- `priv/affidavit/MANIFEST.json` (present and verified)
- `priv/affidavit/affidavit.wasm` (pinned engine byte-identical)
- `LICENSES/MIT.txt`, `LICENSE`, `REUSE.toml` (REUSE compliant)
- `usage-rules.md`, `usage-rules/**` (doctrine documentation)
- `HANDWRITTEN.md` (generator capability fences ledger)
- `CHANGELOG.md` (v26.11.10 entry present)
- `documentation/**` (Diataxis tutorials and DSL docs)

---

## 2. Verification Ladder Executed

1. **Rung 1: `mix format --check-formatted`**: **Exit `0`** — zero formatting drift across repository.
2. **Rung 2: `mix compile --warnings-as-errors`**: **Exit `0`** — 31 source files cleanly compiled with zero warnings.
3. **Rung 3: `mix credo --strict` and `mix sobelow --skip`**:
   - `mix credo --strict`: **Exit `0`** — 50 source files, 435 mods/funs, found 0 issues.
   - `MIX_ENV=test mix sobelow --skip`: **Exit `0`** — static security scan complete with zero high-confidence vulnerabilities.
4. **Rung 4: Wasm Verification & Full Test Suite**:
   - `mix ash_affidavit.verify`: **Exit `0`** — Affidavit engine verified (sha256 `5cc37aea...`, abi_version 1).
   - `mix test`: **Exit `0`** — 169 passed (11 doctests, 158 tests, 0 failures, 5 excluded pack-regeneration tests). Process pool registration collision resolved via `start_supervised!`.
5. **Rung 5: `mix docs --warnings-as-errors`**: **Exit `0`** — ExDoc HTML (`doc/index.html`), Markdown (`doc/llms.txt`), and EPUB (`doc/AshAffidavit.epub`) generated with zero redirect warnings.
6. **Rung 6: Hex Packaging Closure, Tarball Build & Dry-Run Publication**:
   - `mix hex.build --unpack -o _build-lane-m1/pkg_unpack`: **Exit `0`** — package closure asserted.
   - `mix hex.build -o _build-lane-m1/ash_affidavit-26.11.10.tar`: **Exit `0`** — produced 317,952-byte tarball with checksum `ae0acc06e4a184e318e32c18a4f3de0f7e6bd28e40e492daabf8ea63b947f6ee`.
   - `mix hex.publish --dry-run --yes < /dev/null`: **Exit `0`** — passed Hex package validation and dry-run docs publication without live remote publication.

---

## 3. Standing & Residual Pre-Live-Publish Gate Falsifiers

Per `AGENTS.md` and the Chatman Equation (`A = μ(O*)`):
- **Hex Packaging & Dry-Run Court Standing**: `PARTIAL_ALIVE` (all packaging, hygiene, test ladder rungs 1-6, and `mix hex.publish --dry-run` pass locally with exit 0).
- **Residual Falsifiers Before Promoting Release Standing to `ALIVE` / Live `mix hex.publish`**:
  1. **Maintainer Credentials Gate**:
     - `AGENTS.md:57` explicitly dictates: *"Do not run mix hex.publish from an agent session: publishing needs the maintainer's Hex API key."*
  2. **Exact-Head Commit & Remote CI**:
     - Wave changes are staged atop `ffc8dfd4a98946079ced44c530dc4a8e38ad491f`; committing the release tree and witnessing green CI on the exact release tag is required for final `ALIVE` release standing.
