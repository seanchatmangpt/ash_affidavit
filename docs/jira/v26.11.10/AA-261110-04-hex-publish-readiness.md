# Work Order: AA-261110-04 — Hex Publish Readiness & Packaging Gate

- **Key**: `AA-261110-04`
- **Milestone**: `v26.11.10`
- **Component**: Packaging / Release / ExDoc
- **Status**: IMPLEMENTED / VERIFIED
- **Type**: Release Gate

---

## 1. Problem Statement

1. **ExDoc Redirection Warning**:
   Running `mix docs --warnings-as-errors` failed because `main: "readme"` in `mix.exs` caused `index.html` to redirect to `readme.html`, which did not exist due to duplicate title/slug collisions between root `README.md` and `docs/diataxis/README.md`.
2. **Directory Taxonomy Law Violation**:
   The folder `docs/diataxis/reference/generated/` violated the global rule banning generic `generated` directories, and contained hardcoded absolute paths `/Users/sac/...`.
3. **Packaging Hygiene**:
   `ash_affidavit-*/` was untracked in `.gitignore`, risking dirty working trees during unpack inspections.
4. **Hex Publishing Safety**:
   Operating doctrine and `AGENTS.md:57` forbid executing live `mix hex.publish` from agent sessions. A repeatable local gate was required to certify release readiness without requiring maintainer credentials.

---

## 2. Implementation Summary

1. **ExDoc Configuration**:
   Explicitly mapped filenames in `mix.exs:extras`:
   - `{"README.md", title: "Home", filename: "readme"}`
   - `{"docs/diataxis/README.md", title: "Documentation Map", filename: "diataxis_map"}`
   - `{"docs/diataxis/reference/descriptors/README.md", title: "API Descriptors Map", filename: "descriptors_map"}`
   Added `AshAffidavit.ChainVerifier` to `groups_for_modules: [API: ...]`.
2. **Directory Taxonomy Migration**:
   Moved `docs/diataxis/reference/generated/` to `docs/diataxis/reference/descriptors/`.
   Removed hardcoded `/Users/sac/...` paths and replaced with portable environment fallback `${MARKETPLACE_ROOT:-...}`.
   Updated cross-links in `docs/diataxis/README.md`.
3. **Gitignore Update**:
   Added `/ash_affidavit-*/` to `.gitignore`.
4. **Hex Release Court**:
   Executed `mix hex.build --unpack` and verified package boundary closure.
   Executed `mix hex.publish --dry-run --yes < /dev/null`.

---

## 3. Verification Method & Output

```sh
export MIX_BUILD_ROOT=_build-lane-m1
mix docs --warnings-as-errors
mix hex.build --unpack -o _build-lane-m1/pkg_unpack
mix hex.build -o _build-lane-m1/ash_affidavit-26.11.10.tar
mix hex.publish --dry-run --yes < /dev/null
```
- All commands exit code 0.
