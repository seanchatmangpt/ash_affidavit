# TODO-FIX-AND-FINISH (ash_affidavit)

Standing: UNVERIFIED

Source: PROJECT-REVIEWS.md R2; line numbers re-read where marked confirmed.

## Fix

- HIGH `lib/ash_affidavit/signing.ex:457-463` `hex_arg/2` never validates hex: last `and`
  operand is `Base.decode16/2` returning `{:ok,_}|:error` (truthy), confirmed. Check: test that
  non-hex even-length binary is rejected or documented as raw bytes.
- MED `signing.ex:352-356` `decode_subject_digest_payload/2` has no `else`, returns bare
  `:error` (confirmed); caller CaseClauseError UNVERIFIED. Check: returns typed error tuple.
- MED `chain_verifier.ex:29-42` verifies against caller-supplied key only: self-consistency,
  not authenticity; docs silent (UNVERIFIED this lane). Check: moduledoc states it.
- MED stale docs: `signing.ex:11-21` moduledoc and `chain_verifier.ex:8-12` delegation claim
  (UNVERIFIED this lane). Check: docs match code.
- LOW `signing/keys.ex:139-147` PQ/unknown algs unchecked; mislabelled RFC 8032 vector; vacuous
  `doctest ChainVerifier` (UNVERIFIED).

## Finish

- Add raw-bytes path test for `hex_arg/2`. Check: `mix test` includes it.
- Real doctests or remove vacuous one. Check: doctest asserts a result.

## Commit hygiene

- Untracked `docs/diataxis/reference/descriptors/` is referenced by `mix.exs:138-141` extras
  (confirmed). Check: tracked, `mix docs` passes on fresh clone.
- Old `docs/diataxis/reference/generated/*` deleted, unstaged (confirmed ` D`). Check: commit
  the deletion with the descriptors.
- Untracked `test/ash_affidavit_chain_verifier_test.exs`, `docs/sjira/v26.11.10/`, `docs/jira/`.
- Many modified docs/README/CHANGELOG uncommitted (`git status --short`).

## Decide

- Whether chain verification must bind to a trusted key registry (authenticity).
- Reject vs accept raw bytes as hex input.

## Reuse

- `lib/ash_affidavit/refusal.ex:91-189` closed code-to-class refusal registry, compile-time atoms.
- `lib/ash_affidavit/signing/keys.ex:139-220` key-shape laws as declarative refinements.

## See Also

`ash_surface/docs/jira/v26.11.11/PROJECT-REVIEWS.md`
