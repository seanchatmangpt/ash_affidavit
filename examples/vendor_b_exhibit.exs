# Vendor B (ash_affidavit) conference-sim exhibit script - lane EV14.
#
# Run from the ash_affidavit checkout:
#   RESULT_PATH=/tmp/exhibit.json MIX_BUILD_ROOT=_build-ev14b \
#     mix run --no-start examples/vendor_b_exhibit.exs
#
# Signs a conference credential over the REAL pinned wasm through the
# repo's own AshAffidavit.Signing surface, and emits a JSON exhibit (JWKS,
# public subject registry, credential, engine witness) - the only thing
# crossing the vendor boundary. The venue never sees the private key.
#
# Engine law note: the pinned engine's envelope canonicalizer accepts only
# ES256 / ML-DSA / SLH-DSA / hybrid envelope algorithms (Ed25519 is in the
# AG1 key-set but NOT a valid envelope `algorithm` wire form - witnessed:
# "unknown algorithm wire form" refusal on "Ed25519"), so the exhibit
# credentials are ES256, and Ed25519's host-crypto verify path is therefore
# the ES256 :crypto path on the venue side.

defmodule VendorB.Exhibit do
  @domain_tag "affidavit.crypto-trust-plane.v1"
  @envelope_version "CTP-ENVELOPE-v1"

  def run do
    {:ok, _} = Application.ensure_all_started(:ash_affidavit)
    {:ok, host} = AshAffidavit.Host.start_link(name: nil, bytes: File.read!("priv/affidavit/affidavit.wasm"))
    opts = [server: host]

    # The exhibitor's signing key: ECDSA P-256 (ES256), published as a JWKS.
    priv_int = :crypto.strong_rand_bytes(32) |> :binary.decode_unsigned()
    {pub_point, _priv} = :crypto.generate_key(:ecdh, :secp256r1, priv_int)

    kid =
      "afk1_" <> (Base.encode16(:crypto.hash(:sha256, <<priv_int::unsigned-size(256)>>), case: :lower) |> binary_part(0, 16))

    # Engine-derived subject digests (public, registered at the door).
    {:ok, %{digest: subject_x}} = AshAffidavit.Signing.derive_subject_digest(@domain_tag, "attendee-X", opts)
    {:ok, %{digest: subject_y}} = AshAffidavit.Signing.derive_subject_digest(@domain_tag, "attendee-Y", opts)

    payload = %{
      "attendee" => "attendee-X",
      "badge_class" => "exhibitor-guest",
      "issued_at" => System.system_time(:second)
    }

    envelope = %{
      "version" => "CTP-ENVELOPE-v1",
      "algorithm" => "ES256",
      "key_id" => kid,
      "profile" => "CLASSICAL",
      "policy_epoch" => 1,
      "revocation_epoch" => 0,
      "generation" => 1,
      "nonce" => Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
      "not_before" => System.system_time(:second) - 60,
      "expires_at" => System.system_time(:second) + 3600,
      "subject_digest" => Base.encode16(subject_x, case: :lower),
      "audience" => "conference-sim.venue"
    }

    # The engine recomputes the signing pre-image over the envelope bytes.
    {:ok, pre_image_hex} = AshAffidavit.Signing.signing_input(envelope, opts)
    pre_image = Base.decode16!(pre_image_hex, case: :lower)

    # Host-side ES256 signature over the engine-derived pre-image,
    # normalized to the engine's low-s canonical form.
    signature = :crypto.sign(:ecdsa, :sha256, pre_image, [priv_int, :secp256r1]) |> low_s_normalize()

    # Engine witness: the exhibitor's own wasm adjudicates the signature
    # (ES256 = DER low-s; :crypto emits DER).
    {:ok, %{valid: true}} =
      AshAffidavit.Signing.verify_signature(
        %{"alg" => "ES256", "public_key_hex" => Base.encode16(pub_point, case: :lower)},
        Base.encode16(signature, case: :lower),
        pre_image_hex,
        opts
      )

    exhibit = %{
      "kid" => kid,
      "jwks" => %{
        "keys" => [
          %{
            "kty" => "EC",
            "crv" => "P-256",
            "alg" => "ES256",
            "kid" => kid,
            "sec1" => Base.url_encode64(pub_point, padding: false)
          }
        ]
      },
      # Public subject registry: engine-derived digests, one per attendee.
      "subject_registry" => %{
        "attendee-X" => Base.encode16(subject_x, case: :lower),
        "attendee-Y" => Base.encode16(subject_y, case: :lower)
      },
      "credential" => %{
        "envelope" => envelope,
        "signature_hex" => Base.encode16(signature, case: :lower),
        "payload" => payload,
        "payload_hash_hex" => Base.encode16(:crypto.hash(:sha256, Jason.encode!(payload)), case: :lower)
      },
      # What Vendor B's engine witnessed, for cross-engine agreement checks.
      "engine_witness" => %{"signing_input_hex" => pre_image_hex, "sig_valid" => true}
    }

    File.write!(System.fetch_env!("RESULT_PATH"), Jason.encode!(exhibit))
    GenServer.stop(host)
  end


  # The engine's ES256 law admits only low-s DER signatures; :crypto emits
  # whichever of s / n - s the randomness lands on, so normalize: DER
  # SEQUENCE { INTEGER r, INTEGER s }, s := min(s, n - s).
  defp low_s_normalize(der) do
    {r, s} = parse_two_integers(der)
    s_low = min(s, p256_n() - s)
    IO.iodata_to_binary(wrap_sequence([der_integer(r), der_integer(s_low)]))
  end

  # DER SEQUENCE (0x30 len) wrapping two INTEGER TLVs; the signature is
  # exactly two INTEGERs, so the header is re-emitted with the new length.
  defp wrap_sequence(body) do
    body = IO.iodata_to_binary(body)
    <<0x30, byte_size(body), body::binary>>
  end

  defp der_integer(int) when int > 0 do
    b = :binary.encode_unsigned(int)
    b = if :binary.at(b, 0) >= 128, do: <<0, b::binary>>, else: b
    <<0x02, byte_size(b), b::binary>>
  end

  defp p256_n, do: 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551

  # Parse the two INTEGER TLVs of a two-integer DER SEQUENCE body.
  defp parse_two_integers(der) do
    # skip the SEQUENCE header (0x30 + short-form length: a two-integer
    # signature is always < 128 bytes total).
    <<0x30, _len, rest::binary>> = der
    {r, rest2} = parse_integer(rest)
    {s, _} = parse_integer(rest2)
    {r, s}
  end

  defp parse_integer(<<0x02, len, rest::binary>>) do
    <<val::binary-size(len), tail::binary>> = rest
    {:binary.decode_unsigned(val), tail}
  end




end
VendorB.Exhibit.run()
