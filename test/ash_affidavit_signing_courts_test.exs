# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# Lane AG2 (v26.10.5 wave): courts for the signing surface. Real collaborators only: the real
# pinned wasm answers every `verify_signature_input` call; the KAT vectors are the engine
# repository's own rendered known-answer fixtures (fixtures/crypto_trust_kat_vectors.json),
# hardcoded here so the host binding is held to the real generator's output, not to itself.

defmodule AshAffidavit.SigningCourtsTest do
  use ExUnit.Case, async: false

  alias AshAffidavit.Refusal
  alias AshAffidavit.Signing
  alias AshAffidavit.Signing.Keys

  doctest Signing

  setup_all do
    {:ok, _} = Application.ensure_all_started(:ash_affidavit)
    {:ok, _} = AshAffidavit.Pool.start_link([])
    {:ok, _} = AshAffidavit.Host.start_link(name: nil, bytes: File.read!("priv/affidavit/affidavit.wasm"))
    on_exit(fn -> Application.delete_env(:ash_affidavit, :start_pool) end)
    :ok
  end

  # KAT vector env-000-ES256 (from the engine's rendered crypto-trust KAT fixture).
  @kat_envelope %{
    "version" => "CTP-ENVELOPE-v1",
    "algorithm" => "ES256",
    "audience" => "affidavit.kat",
    "expires_at" => 4_102_444_800,
    "generation" => 1,
    "key_id" => "afk1_a9c3bd446195e2e2",
    "nonce" => [25, 107, 217, 46, 141, 94, 95, 54, 120, 72, 204, 59, 49, 154, 244, 42],
    "not_before" => 1_700_000_000,
    "policy_epoch" => 1,
    "profile" => "CLASSICAL",
    "revocation_epoch" => 0,
    "subject_digest" => [
      206,
      63,
      11,
      26,
      126,
      80,
      218,
      245,
      190,
      191,
      110,
      203,
      240,
      54,
      52,
      94,
      36,
      141,
      20,
      88,
      5,
      127,
      63,
      121,
      250,
      128,
      109,
      66,
      210,
      110,
      68,
      97
    ]
  }
  @kat_signing_input_hex "6166666964617669742e63727970746f2d74727573742d706c616e652e763100" <>
                           "6166666964617669742e63727970746f2d74727573742d706c616e652e763100" <>
                           "00000000000001ac7b22616c676f726974686d223a224553323536222c226175" <>
                           "6469656e6365223a226166666964617669742e6b6174222c2265787069726573" <>
                           "5f6174223a343130323434343830302c2267656e65726174696f6e223a312c22" <>
                           "6b65795f6964223a2261666b315f61396333626434343631393565326532222c" <>
                           "226e6f6e6365223a5b32352c3130372c3231372c34362c3134312c39342c3935" <>
                           "2c35342c3132302c37322c3230342c35392c34392c3135342c3234342c34325d" <>
                           "2c226e6f745f6265666f7265223a313730303030303030302c22706f6c696379" <>
                           "5f65706f6368223a312c2270726f66696c65223a22434c4153534943414c222c" <>
                           "227265766f636174696f6e5f65706f6368223a302c227375626a6563745f6469" <>
                           "67657374223a5b3230362c36332c31312c32362c3132362c38302c3231382c32" <>
                           "34352c3139302c3139312c3131302c3230332c3234302c35342c35322c39342c" <>
                           "33362c3134312c32302c38382c352c3132372c36332c3132312c3235302c3132" <>
                           "382c3130392c36362c3231302c3131302c36382c39375d2c2276657273696f6e" <>
                           "223a224354502d454e56454c4f50452d7631227d"

  # ---- court 1: the real pinned engine verifies the honest pre-image ------------------------

  @tag :signing
  test "a well-formed envelope verifies against its KAT pre-image on the real pinned engine" do
    {:ok, engine_pre_image} = Signing.signing_input(@kat_envelope)

    assert {:ok,
            %{
              verified_pre_image: true,
              signing_input_hex: ^engine_pre_image,
              subject_binding: :unchecked
            }} =
             Signing.verify_certified_receipt(@kat_envelope, String.duplicate("ab", 32), "s1",
               expected_signing_input_hex: engine_pre_image
             )
  end

  # ---- court 2: tampered document -> decided-negative, typed refusal taxonomy intact ---------

  @tag :signing
  test "a tampered envelope is a decided-negative mismatch, and a tampered subject binding refuses" do
    {:ok, honest} = Signing.signing_input(@kat_envelope)
    # The engine's recomputed pre-image is byte-identical to the rendered KAT vector's
    # signing_input_hex (env-000-ES256, engine repo tests/crypto_abi.rs) — the host binding is
    # held to the real generator's output, not to itself.
    assert honest == @kat_signing_input_hex
    tampered = Map.put(@kat_envelope, "audience", "affidavit.kau")

    assert {:ok, %{verified_pre_image: false, signing_input_hex: other}} =
             Signing.verify_certified_receipt(tampered, String.duplicate("ab", 32), "s1",
               expected_signing_input_hex: honest
             )

    refute other == honest

    # A caller-attested subject digest the envelope does not bind is a host refusal, decided
    # before the engine is consulted.
    assert {:refused, %Refusal{code: :bad_field, message: m}} =
             Signing.verify_certified_receipt(@kat_envelope, String.duplicate("ab", 32), "s1",
               expected_signing_input_hex: honest,
               expected_subject_digest: <<1, 2, 3>>
             )

    assert m =~ "subject_digest"
  end

  # ---- court 3: host-side typed gates --------------------------------------------------------

  @tag :signing
  test "shape and field-closure gates refuse with typed codes before any engine call" do
    assert {:refused, %Refusal{code: :missing_field}} = Signing.verify_certified_receipt(:nope, "x", "s")

    bad_payload = Signing.verify_certified_receipt(@kat_envelope, "zz", "s")
    assert {:refused, %Refusal{code: :bad_field, message: m}} = bad_payload
    assert m =~ "payload_hash"

    assert {:refused, %Refusal{code: :bad_field, message: m2}} =
             Signing.verify_certified_receipt(@kat_envelope, String.duplicate("ab", 32), "")

    assert m2 =~ "subject"

    missing_field = Map.delete(@kat_envelope, "key_id")

    assert {:refused, %Refusal{code: :missing_field, details: %{field: "key_id"}}} =
             Signing.verify_certified_receipt(missing_field, String.duplicate("ab", 32), "s")

    wrong_version = Map.put(@kat_envelope, "version", "CTP-ENVELOPE-v2")

    assert {:refused, %Refusal{code: :bad_field, details: %{field: "version"}}} =
             Signing.verify_certified_receipt(wrong_version, String.duplicate("ab", 32), "s")
  end

  # ---- court 4: engine refusals pass through typed ------------------------------------------

  @tag :signing
  test "an absent expectation is the engine's own typed refusal, passed through" do
    assert {:refused, %Refusal{code: :bad_field, message: m}} =
             Signing.verify_certified_receipt(@kat_envelope, String.duplicate("ab", 32), "s1")

    assert m =~ "expected_signing_input_hex"
  end

  # ---- court 5: hex-normalized digest forms canonicalize identically -------------------------

  @tag :signing
  test "hex and byte-array forms of nonce/subject_digest produce the same engine pre-image" do
    {:ok, from_bytes} = Signing.signing_input(@kat_envelope)

    hex_form =
      Map.merge(@kat_envelope, %{
        "nonce" => Base.encode16(:binary.list_to_bin(@kat_envelope["nonce"])),
        "subject_digest" => @kat_envelope["subject_digest"] |> :binary.list_to_bin() |> Base.encode16()
      })

    assert {:ok, from_hex} = Signing.signing_input(hex_form)
    assert from_hex == from_bytes
  end

  # ---- court 6: JWKS helpers ------------------------------------------------------------------

  @tag :signing
  test "from_jwks normalizes a real document and select/2 routes by kid with a closed alg set" do
    jwks = %{
      "keys" => [
        %{
          "kid" => "afk1_a9c3bd446195e2e2",
          "kty" => "EC",
          "alg" => "ES256",
          "crv" => "P-256",
          "x" => "SqxAF1mVne2n4VF8wo48LXc6mrLUpZOY_UtrYBr6-tE",
          "y" => "s4ioBpL_T8-pl2bL8vJXXMRTuaf92qzvJfbaxOdzOu8"
        },
        %{"kid" => "afk1_932a436a743d67cd", "kty" => "OKP", "alg" => "ML_DSA65"}
      ]
    }

    assert {:ok, [k1, k2] = keys} = Keys.from_jwks(jwks)
    assert k1["kid"] == "afk1_a9c3bd446195e2e2"
    assert k1["crv"] == "P-256"
    assert k2["alg"] == "ML_DSA65"

    assert {:ok, selected} = Keys.select(keys, "afk1_932a436a743d67cd")
    assert selected["kty"] == "OKP"

    assert {:error, %Refusal{code: :bad_field, details: %{kid: "nope"}}} = Keys.select(keys, "nope")

    rogue = %{"kid" => "afk1_0000000000000000", "kty" => "EC", "alg" => "RSA-OAEP"}
    assert {:error, %Refusal{code: :bad_field, message: m}} = Keys.select([rogue], "afk1_0000000000000000")
    assert m =~ "closed algorithm set"
  end

  @tag :signing
  test "broken JWKS documents refuse typed" do
    assert {:error, %Refusal{code: :invalid_json}} = Keys.from_jwks("{not json")
    assert {:error, %Refusal{code: :missing_field}} = Keys.from_jwks(%{})
    assert {:error, %Refusal{code: :bad_field}} = Keys.from_jwks(%{"keys" => "many"})
    assert {:error, %Refusal{code: :missing_field}} = Keys.from_jwks(%{"keys" => [%{"kty" => "EC"}]})

    assert {:error, %Refusal{code: :bad_field}} =
             Keys.from_jwks(%{"keys" => [%{"kid" => "k", "kty" => "RSA", "alg" => "RS256"}]})
  end

  # ---- court 7: structural key validation admits well-formed material per algorithm ----------

  @ed25519_x "AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA"
  @ec_xy "AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA"

  @tag :signing
  test "structurally valid keys pass validation for every classical family" do
    ed = %{"kid" => "k_ed", "kty" => "OKP", "alg" => "ED25519", "x" => @ed25519_x}
    es256_jwk = %{"kid" => "k_es", "kty" => "EC", "alg" => "ES256", "crv" => "P-256", "x" => @ec_xy, "y" => @ec_xy}

    es256_sec1 = %{
      "kid" => "k_es_sec1",
      "kty" => "EC",
      "alg" => "ES256",
      "sec1" => <<0x04>> <> :binary.copy(<<1>>, 64)
    }

    es256k_sec1 = %{"kid" => "k_k_sec1", "kty" => "EC", "alg" => "ES256K", "sec1" => <<0x03>> <> :binary.copy(<<1>>, 32)}

    es256k_jwk = %{"kid" => "k_k_jwk", "kty" => "EC", "alg" => "ES256K", "x" => @ec_xy, "y" => @ec_xy}

    # LENGTH-DYNAMIC (TODO AG1): PQ/hybrid families have no pinned length law in this tree yet.
    pq = %{"kid" => "k_pq", "kty" => "OKP", "alg" => "ML_DSA65"}

    assert {:ok, keys} = Keys.from_jwks(%{"keys" => [ed, es256_jwk, es256_sec1, es256k_sec1, es256k_jwk, pq]})
    assert length(keys) == 6
  end

  @tag :signing
  test "wrong-length, truncated, wrong-prefix and duplicate-source material refuse typed" do
    short_ed = %{"kid" => "bad_ed", "kty" => "OKP", "alg" => "ED25519", "x" => "AQIDBAUGBwgJCgsMDQ4PEA"}

    assert {:error, %Refusal{code: :bad_field, message: m}} = Keys.from_jwks(%{"keys" => [short_ed]})
    assert m =~ "32 bytes"

    assert {:error, %Refusal{code: :missing_field}} =
             Keys.from_jwks(%{"keys" => [%{"kid" => "no_x", "kty" => "OKP", "alg" => "ED25519"}]})

    short_xy = %{"kid" => "bad_xy", "kty" => "EC", "alg" => "ES256", "x" => @ec_xy, "y" => "AQIDBAUGBwgJCgsMDQ4PEA"}

    assert {:error, %Refusal{code: :bad_field, message: m2}} = Keys.from_jwks(%{"keys" => [short_xy]})
    assert m2 =~ "32 bytes each"

    wrong_prefix = %{"kid" => "bad_sec1", "kty" => "EC", "alg" => "ES256", "sec1" => <<0x03>> <> :binary.copy(<<1>>, 64)}

    assert {:error, %Refusal{code: :bad_field, message: m3}} = Keys.from_jwks(%{"keys" => [wrong_prefix]})
    assert m3 =~ "0x04"

    wrong_prefix_k = %{"kid" => "bad_sec1k", "kty" => "EC", "alg" => "ES256K", "sec1" => <<0x04>> <> :binary.copy(<<1>>, 64)}

    assert {:error, %Refusal{code: :bad_field, message: m4}} = Keys.from_jwks(%{"keys" => [wrong_prefix_k]})
    assert m4 =~ "0x02 or 0x03"

    both = %{"kid" => "both", "kty" => "EC", "alg" => "ES256", "sec1" => <<0x04>> <> :binary.copy(<<1>>, 64), "x" => @ec_xy, "y" => @ec_xy}

    assert {:error, %Refusal{code: :bad_field, message: m5}} = Keys.from_jwks(%{"keys" => [both]})
    assert m5 =~ "both"
  end

  @tag :signing
  test "base64url padding and non-base64url material refuse with :invalid_encoding" do
    padded = %{"kid" => "padded", "kty" => "OKP", "alg" => "ED25519", "x" => @ed25519_x <> "="}

    assert {:error, %Refusal{code: :invalid_encoding, message: m}} = Keys.from_jwks(%{"keys" => [padded]})
    assert m =~ "unpadded base64url"

    std_b64 = %{
      "kid" => "std",
      "kty" => "EC",
      "alg" => "ES256",
      "x" => "AQ+D",
      "y" => @ec_xy
    }

    assert {:error, %Refusal{code: :invalid_encoding}} = Keys.from_jwks(%{"keys" => [std_b64]})
  end

  # ---- court 8: verify_signature over the real pinned engine (RFC 8032 Ed25519 KAT) ----------

  # RFC 8032 test vector 2, the same in-tree KAT the engine's own verify_signature op tests use.
  @ed_key "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"
  @ed_input_hex "72"
  @ed_sig "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"

  @tag :signing
  test "a real Ed25519 signature verifies through the engine's verify_signature op" do
    assert {:ok, %{valid: true, refusal: nil, alg: "Ed25519"}} =
             Signing.verify_signature(
               %{alg: "Ed25519", public_key_hex: @ed_key},
               @ed_sig,
               @ed_input_hex
             )
  end

  @tag :signing
  test "a tampered input is a decided-negative, and broken material is a typed refusal" do
    # One flipped input bit: well-formed material, wrong bytes -> valid:false, not a refusal.
    assert {:ok, %{valid: false, refusal: :verification_failed}} =
             Signing.verify_signature(
               %{alg: "Ed25519", public_key_hex: @ed_key},
               @ed_sig,
               "73"
             )

    # A key of the right family but wrong length: the engine's typed refusal, mapped.
    assert {:refused, %Refusal{code: :bad_field, message: m, details: %{alg: "Ed25519"}}} =
             Signing.verify_signature(
               %{alg: "Ed25519", public_key_hex: "aabb"},
               @ed_sig,
               @ed_input_hex
             )

    assert m =~ "malformed_public_key"

    # An algorithm outside the engine's set: :unsupported, never a false "invalid".
    assert {:unsupported, %Refusal{code: :unknown_op}} =
             Signing.verify_signature(
               %{alg: "ML_DSA65", public_key_hex: @ed_key},
               @ed_sig,
               @ed_input_hex
             )

    # Missing key material and non-binary inputs are host refusals before any engine call.
    assert {:refused, %Refusal{code: :missing_field}} =
             Signing.verify_signature(%{alg: "Ed25519"}, @ed_sig, @ed_input_hex)

    assert {:refused, %Refusal{code: :bad_field}} =
             Signing.verify_signature(%{alg: "Ed25519", public_key_hex: @ed_key}, 7, @ed_input_hex)
  end

  @tag :signing
  test "an envelope as key source routes by its algorithm field" do
    assert {:refused, %Refusal{code: :missing_field, message: m}} =
             Signing.verify_signature(@kat_envelope, @ed_sig, @ed_input_hex)

    assert m =~ "public key"

    # Routing follows the envelope's own `algorithm` field (ES256 here): an Ed25519 key under
    # ES256 is the engine's typed malformed_public_key refusal, decided by the routed alg.
    assert {:refused, %Refusal{code: :bad_field, message: routed}} =
             Signing.verify_signature(@kat_envelope, @ed_sig, @ed_input_hex,
               public_key_hex: @ed_key
             )

    assert routed =~ "ES256"
  end

  # ---- court 9: derive_subject_digest over the real pinned engine (Rust-side KAT) -------------

  # KAT extracted from the engine repo's crypto.rs: the rendered plane's
  # crypto_trust_canonical::digest_hex law, DOMAIN_TAG "affidavit-paid-delivery/v1",
  # computed against blake3 1.8.5 (the pinned crate in the engine's Cargo.lock).
  @kat_tag "affidavit-paid-delivery/v1"
  @kat_subject "paid-delivery:evt-001"
  @kat_digest_hex "3ca4fb8419bd2319a832f8c9b2a5e2d8f2e8105c17d5fc6115de0238a7ec5e3f"

  @tag :signing
  test "derive_subject_digest matches the Rust-side KAT and audits its pre-image" do
    assert {:ok, %{digest_hex: digest_hex, pre_image_hex: pre_hex, digest: digest}} =
             Signing.derive_subject_digest(@kat_tag, @kat_subject)

    assert digest_hex == @kat_digest_hex
    assert byte_size(digest) == 32

    # The pre-image audit field: tag twice, 0x00 separators, u64-be length, then the subject.
    {:ok, pre} = Base.decode16(pre_hex, case: :lower)
    tag_bytes = @kat_tag

    assert pre ==
             tag_bytes <> <<0>> <> tag_bytes <> <<0>> <> <<byte_size(@kat_subject)::size(64)>> <> @kat_subject
  end

  @tag :signing
  test "cross-domain derivation differs and an empty domain tag refuses typed" do
    {:ok, a} = Signing.derive_subject_digest(@kat_tag, "x")
    {:ok, b} = Signing.derive_subject_digest("affidavit.other-domain/v1", "x")

    refute a.digest_hex == b.digest_hex

    assert {:refused, %Refusal{code: :bad_field}} = Signing.derive_subject_digest("", "x")
  end

  # ---- court 10: engine-derived subject binding in verify_certified_receipt (AG2r gap #2) -----

  @envelope_tag "affidavit.crypto-trust-plane.v1"

  @tag :signing
  test "an engine-derived digest binds the envelope where the caller-attested path stays green" do
    {:ok, honest} = Signing.signing_input(@kat_envelope)

    # The AG2r byte-identical pre-image court stays green: caller-attested path unchanged.
    assert {:ok, %{verified_pre_image: true, subject_binding: :unchecked}} =
             Signing.verify_certified_receipt(@kat_envelope, String.duplicate("ab", 32), "s1",
               expected_signing_input_hex: honest
             )

    # Engine-derived: digest "s1" under the envelope domain tag through the engine and mint an
    # envelope that binds it. The derivation is the engine's, not the caller's.
    {:ok, %{digest: digest}} = Signing.derive_subject_digest(@envelope_tag, "s1")
    bound = Map.merge(@kat_envelope, %{"subject_digest" => :binary.bin_to_list(digest)})

    assert {:ok, %{subject_binding: :verified, subject_binding_source: :engine_derived}} =
             Signing.verify_certified_receipt(bound, String.duplicate("ab", 32), "s1",
               expected_signing_input_hex: honest,
               domain_tag: @envelope_tag
             )

    # The same envelope with a subject it does not bind refuses on the engine-derived check.
    assert {:refused, %Refusal{code: :bad_field, message: m}} =
             Signing.verify_certified_receipt(bound, String.duplicate("ab", 32), "s2",
               expected_signing_input_hex: honest,
               domain_tag: @envelope_tag
             )

    assert m =~ "engine-derived"
  end
end
