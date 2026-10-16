# How To: Verify a Signature Envelope

Goal: load key material from a JWKS, adjudicate a signature and bind a subject
through the engine's signing ops — using `AshAffidavit.Signing`,
`AshAffidavit.Signing.Keys` and the `CTP-ENVELOPE-v1` document laws.

## Prerequisites

- `ash_affidavit` 26.10.16 with the pool running
  (`config :ash_affidavit, start_pool: true`).
- The pinned engine exposes the signing ops: `verify_signature_input`,
  `verify_signature` and `derive_subject_digest`. The pinned artifact is
  `5cc37aea...` (`priv/affidavit/MANIFEST.json`); `AshAffidavit.ops/0` returns
  the closed op list.

## 1. Load key material from a JWKS

`AshAffidavit.Signing.Keys.from_jwks/2`
(`lib/ash_affidavit/signing/keys.ex:35`) decodes a JWKS document — a map with
`"keys"`, or its JSON bytes — into a normalized key list. Keys missing `kid`,
`kty` or `alg` are refused. Each admitted key is structurally validated
against its algorithm's shape law (`lib/ash_affidavit/signing/keys.ex:137-204`):

- Ed25519 `x`: unpadded base64url decoding to exactly 32 bytes.
- ES256: JWK `x`+`y` (32 bytes each) or a 65-byte SEC1 uncompressed point
  (`0x04` prefix); ES256K: JWK `x`+`y` or a 33-byte compressed point
  (`0x02`/`0x03` prefix). Carrying both forms refuses `:bad_field`.
- PQ/hybrid families (`ML_DSA65`, `SLH_DSA_SHA2_128s`,
  `HYBRID_ES256_ML_DSA65`) are length-dynamic pending the AG1 envelope field
  set (TODO in `lib/ash_affidavit/signing/keys.ex`).

Material members must be unpadded base64url; padding or standard-base64
characters refuse `:invalid_encoding`. The admitted algorithm-name set is
`AshAffidavit.Signing.Keys.algorithms/0`; a key naming an algorithm outside
the set is kept but refused by `select/2`
(`lib/ash_affidavit/signing/keys.ex:21-23`, `:101-103`).

```elixir
{:ok, keys} = AshAffidavit.Signing.Keys.from_jwks(jwks_document)
{:ok, key} = AshAffidavit.Signing.Keys.select(keys, kid)
```

## 2. Adjudicate one signature

`AshAffidavit.Signing.verify_signature/4`
(`lib/ash_affidavit/signing.ex:374-401`) routes by algorithm — from an
envelope's `"algorithm"` field or a key-material map's `"alg"` — and calls the
engine's `verify_signature` op with `alg`, `public_key_hex`, `signature_hex`
and `signing_input_hex` (`lib/ash_affidavit/signing.ex:385-391`). The engine
answers per-alg: ES256 DER low-s, ES256K fixed 64-byte low-s over a compressed
SEC1 key, Ed25519 strict.

```elixir
case AshAffidavit.Signing.verify_signature(
       %{"alg" => "Ed25519", "public_key_hex" => key_hex},
       signature,
       signing_input
     ) do
  {:ok, %{valid: true, refusal: nil, alg: "Ed25519"}} -> :accepted
  {:ok, %{valid: false, refusal: :verification_failed}} -> :rejected
  {:refused, refusal} -> :malformed_material
  {:unsupported, refusal} -> :unknown_algorithm
end
```

`valid: false` with `refusal: :verification_failed` is a decided-negative
engine answer (a well-formed key/signature over the wrong bytes), not a
refusal. Encoded-but-broken material (`malformed_public_key`/
`malformed_signature`) maps to `{:refused, :bad_field}`; an algorithm outside
the engine's set maps to `{:unsupported, :unknown_op}`
(`lib/ash_affidavit/signing.ex:460-469`). `signature` and `signing_input`
accept raw bytes or hex strings; an even-length decodable hex string is taken
as hex, anything else is hex-encoded
(`lib/ash_affidavit/signing.ex:448-456`).

## 3. Verify an envelope's pre-image binding

An envelope is the 12 signed fields of `CTP-ENVELOPE-v1`
(`lib/ash_affidavit/signing.ex:65-78`): `version`, `algorithm`, `key_id`,
`profile` (`CLASSICAL` | `HYBRID` | `PQC`), `policy_epoch`,
`revocation_epoch`, `generation`, `nonce` (16 bytes), `not_before`,
`expires_at`, `subject_digest` (32 bytes), `audience`. Structural laws only —
window/policy/revocation semantics stay with the engine and its verifier.

`AshAffidavit.Signing.verify_certified_receipt/4`
(`lib/ash_affidavit/signing.ex:115-137`) projects the envelope through the
field laws, then asks the engine's `verify_signature_input` op to recompute
the canonical signing pre-image (domain tag, length prefixes, JCS-canonical
document bytes) and compare against `:expected_signing_input_hex`. The result
carries `verified_pre_image` (engine witness) and `subject_binding` (host
witness) separately, because the engine binds neither the payload nor the
subject by itself.

```elixir
{:ok, %{verified_pre_image: true, signing_input_hex: hex, subject_binding: binding}} =
  AshAffidavit.Signing.verify_certified_receipt(
    envelope,
    payload_hash,
    subject,
    expected_signing_input_hex: hex_from_signer
  )
```

`verified_pre_image: false` is a successful engine answer (decided-negative),
not a refusal. Unknown envelope members (e.g. a `signature` field) are
excluded from the signed bytes by the engine's canonicalizer.

## 4. Bind the subject

By default the subject binding is `:unchecked` — the module does not invent a
binding law the trust plane does not define. Two ways to bind:

- Caller-attested (`:expected_subject_digest`, 32 raw bytes or 64 hex chars):
  compared byte-wise with the envelope's `subject_digest` before the engine
  call; the result names the source `:caller_attested`.
- Engine-derived (`:domain_tag`): the expected digest is computed by the
  engine's `derive_subject_digest` op over `subject` under the tag, and the
  envelope must bind exactly those bytes; the result names the source
  `:engine_derived`.

`AshAffidavit.Signing.derive_subject_digest/3`
(`lib/ash_affidavit/signing.ex:330-352`) hashes
`tag || 0x00 || tag || 0x00 || u64_be(len) || subject` with BLAKE3 and returns
`digest_hex`, `pre_image_hex` and the raw `digest`, so the host can audit the
domain separation without re-deriving the law. The default domain tag for
certified receipts is `affidavit.crypto-trust-plane.v1`
(`lib/ash_affidavit/signing.ex:312`).

```elixir
{:ok, %{digest_hex: digest_hex, pre_image_hex: pre_image_hex}} =
  AshAffidavit.Signing.derive_subject_digest("affidavit.crypto-trust-plane.v1", subject)

{:ok, %{subject_binding: :verified, subject_binding_source: :engine_derived}} =
  AshAffidavit.Signing.verify_certified_receipt(
    envelope,
    payload_hash,
    subject,
    domain_tag: "affidavit.crypto-trust-plane.v1"
  )
```

## 5. Recover the canonical pre-image

`AshAffidavit.Signing.signing_input/2`
(`lib/ash_affidavit/signing.ex:148-158`) returns the engine's recomputed
signing pre-image for an envelope: implemented as a `verify_signature_input`
call whose expectation cannot match, so the echo is the engine's
recomputation, never the caller's input. Use it to obtain the bytes a signer
must sign.

```elixir
{:ok, signing_input_hex} = AshAffidavit.Signing.signing_input(envelope)
```

## What the engine does not verify

The engine verifies the pre-image and (with the signing ops) the signature and
subject digest. It does not check window, policy or revocation semantics —
those stay with the engine's verifier — and an envelope verified here carries
no authority: `AshAffidavit.call/2` refuses any response stating an authority
above NONE (`lib/ash_affidavit.ex:132-143`). Declaring a signing operation in
the Ash extension grants no authority either.

## See Also

- `docs/diataxis/reference/public-api.md`
- `docs/diataxis/explanation/outcomes-authority-and-refusals.md`
- `docs/diataxis/tutorials/run-your-first-receipt.md`
