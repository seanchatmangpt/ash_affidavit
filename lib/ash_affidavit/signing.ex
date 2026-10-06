# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a signature-envelope
# surface over the engine's `verify_signature_input` op. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Signing do
  @moduledoc """
  The signature-envelope binding surface over the engine's `verify_signature_input` op.

  ## What this module actually verifies (and what it does not)

  The pinned engine's only signing-surface op is `verify_signature_input`: given an envelope
  document (the 12 signed fields of `CTP-ENVELOPE-v1`) it recomputes the canonical signing
  pre-image — domain tag, length prefixes, JCS-canonical document bytes — and reports whether it
  matches the caller-attested `expected_signing_input_hex`. It does **not** verify a cryptographic
  signature against public key material, and it does **not** derive `subject_digest` (a
  domain-separated BLAKE3 digest); those ops are absent from the pinned wasm ABI
  (`AshAffidavit.ops/0` is the closed op list). This module therefore implements exactly what the
  engine supports:

    * typed host-side gates on the caller's input (shape, field closure, byte widths);
    * the caller-attested subject binding — an equality check of `subject_digest` against an
      expected digest the caller supplies, never a recomputation;
    * the engine's pre-image binding — the one binding the engine can witness — through a real
      `verify_signature_input` call.

  A cryptographic signature over the pre-image, and the BLAKE3 `subject_digest` derivation, are
  **not performed here**. Calling this "verified" without an external signer/verifier would be
  overclaiming; the result carries `verified_pre_image` (engine witness) and `subject_binding`
  (host witness) separately for exactly that reason.

  ## Result

      {:ok, %{verified_pre_image: boolean(),
              signing_input_hex: String.t(),
              subject_binding: :verified | :unchecked}}
      | {:refused | :trap | :unsupported, %AshAffidavit.Refusal{}}

  `verified_pre_image: false` is a successful engine answer (decided-negative), not a refusal —
  the same asymmetry the affidavit `crypto_trust_verify` law uses.

  ## Options

    * `:expected_signing_input_hex` — the caller-attested signing pre-image to compare against.
      Passed through to the engine; a missing or ill-formed value is the engine's own
      `missing_field`/`bad_field` refusal, not a host one.
    * `:expected_subject_digest` — 32 raw bytes (or 64 hex chars) the caller attests the envelope
      binds; compared byte-wise with the envelope's `subject_digest` before the engine call.
    * `:domain_tag` — names the derivation law for the subject binding. When present (and no
      `:expected_subject_digest` is supplied), the expected digest is computed by the engine's
      `derive_subject_digest` op over `subject` under this tag, and the envelope must bind it —
      an engine-derived binding instead of a caller-attested one. Defaults to no derivation
      (binding `:unchecked`).
    * `:server`, `:timeout_ms` — forwarded to `AshAffidavit.call/2`.
  """

  alias AshAffidavit.Refusal

  @envelope_version "CTP-ENVELOPE-v1"

  # The 12 signed fields of CTP-ENVELOPE-v1, with the structural law each must satisfy for the
  # engine's canonicalizer to see a well-formed document at all. Only byte-width/type laws live
  # here; semantic laws (window, policy, revocation) stay with the engine and its verifier.
  @envelope_fields MapSet.new([
                     "version",
                     "algorithm",
                     "key_id",
                     "profile",
                     "policy_epoch",
                     "revocation_epoch",
                     "generation",
                     "nonce",
                     "not_before",
                     "expires_at",
                     "subject_digest",
                     "audience"
                   ])

  # The structural law each field must satisfy for the engine's canonicalizer to see a well-formed
  # document at all. Only byte-width/type laws live here; semantic laws (window, policy,
  # revocation) stay with the engine and its verifier.
  defp field_law("version", value), do: value == @envelope_version
  defp field_law("algorithm", value), do: is_binary(value) and value != ""
  defp field_law("key_id", value), do: is_binary(value) and Regex.match?(~r/^afk1_[0-9a-f]{16}$/, value)
  defp field_law("profile", value), do: value in ["CLASSICAL", "HYBRID", "PQC"]
  defp field_law("policy_epoch", value), do: is_integer(value) and value >= 0
  defp field_law("revocation_epoch", value), do: is_integer(value) and value >= 0
  defp field_law("generation", value), do: is_integer(value) and value in 0..0xFFFFFFFF
  defp field_law("nonce", value), do: digest_shape(value, 16)
  defp field_law("not_before", value), do: is_integer(value) and value >= 0
  defp field_law("expires_at", value), do: is_integer(value) and value >= 0
  defp field_law("subject_digest", value), do: digest_shape(value, 32)
  defp field_law("audience", value), do: is_binary(value) and value != ""

  @doc """
  Verifies a certified (sealed) receipt's envelope binding.

  `envelope` is the envelope document map (the 12 `CTP-ENVELOPE-v1` signed fields; unknown fields
  such as a `signature` member are allowed and are not part of the signed bytes — the engine's
  canonicalizer excludes them). `payload_hash` is the SHA-256 of the attested payload, as 64 hex
  chars or 32 raw bytes; `subject` is the attested subject. Both are gated for shape here and are
  **declared context only**: the engine binds neither (see the module doc), and this module does
  not invent a binding law the trust plane does not define. The digest that binds them is the
  envelope's `subject_digest`, checked only when the caller supplies
  `:expected_subject_digest`.

  Returns `{:ok, map}` on a successfully-decided engine answer (including
  `verified_pre_image: false`), or a typed outcome. Engine refusals (`missing_field` for an
  absent `:expected_signing_input_hex`, `bad_field` for a broken envelope) pass through
  unchanged.
  """
  @spec verify_certified_receipt(map(), binary(), binary(), keyword()) ::
          {:ok, map()} | {:refused, Refusal.t()} | {:trap, Refusal.t()} | {:unsupported, Refusal.t()}
  def verify_certified_receipt(envelope, payload_hash, subject, opts \\ []) do
    with {:ok, projected} <- gate_envelope(envelope),
         :ok <- gate_context(payload_hash, subject),
         {:ok, binding} <- gate_subject_binding(envelope, subject, opts) do
      request = %{
        "op" => "verify_signature_input",
        "envelope_json" => Jason.encode!(projected),
        "expected_signing_input_hex" => opts[:expected_signing_input_hex]
      }

      case AshAffidavit.call(request, Keyword.take(opts, [:server, :timeout_ms])) do
        {:ok, %{"verified" => verified, "signing_input_hex" => pre_image}} ->
          {:ok, Map.merge(%{verified_pre_image: verified, signing_input_hex: pre_image}, binding_source(binding))}

        # The engine's own error envelope; classify exactly as AshAffidavit.call does.
        # A `malformed` code (the engine's refusal for a broken envelope document) is not in the
        # vendored registry, so it arrives as :engine_unclassified — the host gates above keep
        # that off the well-formed path.
        other ->
          other
      end
    end
  end

  @doc """
  The recomputed signing pre-image for `envelope`, as the engine's own canonicalizer witnesses it.

  Implemented as a `verify_signature_input` call whose expectation cannot match (the engine
  refuses an absent expectation and a mismatch echoes the recomputed pre-image), so the echo is
  the engine's recomputation, never the caller's input. Reads `:server`/`:timeout_ms` options.
  """
  @spec signing_input(map(), keyword()) ::
          {:ok, String.t()} | {:refused, Refusal.t()} | {:trap, Refusal.t()} | {:unsupported, Refusal.t()}
  def signing_input(envelope, opts \\ []) do
    case verify_certified_receipt(
           envelope,
           <<0::256>>,
           "af-signing-input-probe",
           Keyword.put(opts, :expected_signing_input_hex, String.duplicate("00", 128))
         ) do
      {:ok, %{signing_input_hex: hex}} -> {:ok, hex}
      {outcome, refusal} -> {outcome, refusal}
    end
  end

  # ---- host gates --------------------------------------------------------------------------

  defp gate_envelope(envelope) when not is_map(envelope),
    do: {:refused, Refusal.new(:missing_field, "envelope must be a map")}

  defp gate_envelope(envelope) do
    # MapSet iteration order is the sorted field order; the first failing field is reported.
    Enum.reduce_while(MapSet.to_list(@envelope_fields), {:ok, %{}}, fn field, {:ok, acc} ->
      with {:ok, value} <- Map.fetch(envelope, field),
           true <- field_law(field, value) do
        {:cont, {:ok, Map.put(acc, field, value)}}
      else
        :error ->
          {:halt,
           {:refused, Refusal.new(:missing_field, "#{field}: missing_field in signature envelope", %{field: field})}}

        false ->
          {:halt, {:refused, Refusal.new(:bad_field, "#{field}: bad_field in signature envelope", %{field: field})}}
      end
    end)
    |> case do
      {:ok, fields} ->
        # The canonical document carries `nonce`/`subject_digest` as byte arrays; a caller's hex
        # string form is normalized so the engine canonicalizes the same document either way.
        {:ok, normalized(fields)}

      refused ->
        refused
    end
  end

  @digest_widths %{"nonce" => 16, "subject_digest" => 32}

  defp normalized(projected) do
    Map.new(projected, fn
      {field, value} when field in ["nonce", "subject_digest"] and is_binary(value) ->
        width = Map.fetch!(@digest_widths, field)

        bytes =
          if byte_size(value) == width do
            value
          else
            Base.decode16!(value, case: :mixed)
          end

        {field, :binary.bin_to_list(bytes)}

      {field, value} ->
        {field, value}
    end)
  end

  defp gate_context(payload_hash, subject) do
    cond do
      not is_binary(payload_hash) or not digest_shape(payload_hash, 32) ->
        {:refused, Refusal.new(:bad_field, "payload_hash must be 32 raw bytes or 64 hex chars")}

      not is_binary(subject) or subject == "" ->
        {:refused, Refusal.new(:bad_field, "subject must be a nonempty binary")}

      true ->
        :ok
    end
  end

  defp gate_subject_binding(envelope, subject, opts) do
    case Keyword.fetch(opts, :expected_subject_digest) do
      :error ->
        # No caller-attested digest: where the caller names the derivation law (a domain tag),
        # the binding is derived through the engine instead of attested by the caller. This is
        # the AG2r ABI-gap closure — the envelope's subject_digest is checked against an
        # engine-computed digest, not an equality the caller asserts.
        case Keyword.fetch(opts, :domain_tag) do
          :error ->
            {:ok, {:unchecked, :unchecked}}

          {:ok, domain_tag} ->
            engine_derive_binding(envelope, subject, domain_tag, opts)
        end

      {:ok, expected} ->
        expected_bytes = normalize_digest(expected)
        subject_digest = normalize_digest(envelope["subject_digest"])

        cond do
          expected_bytes == :error ->
            {:refused, Refusal.new(:bad_field, "expected_subject_digest must be 32 raw bytes or 64 hex chars")}

          subject_digest == expected_bytes ->
            {:ok, {:verified, :caller_attested}}

          true ->
            {:refused,
             Refusal.new(:bad_field, "envelope subject_digest does not bind the caller-attested digest", %{
               expected: inspect(expected_bytes, limit: 40),
               envelope: inspect(envelope["subject_digest"], limit: 40)
             })}
        end
    end
  end

  # Engine-derived subject binding: digest `subject` under `domain_tag` through the engine's
  # `derive_subject_digest` op and require the envelope to bind exactly those bytes.
  defp engine_derive_binding(envelope, subject, domain_tag, opts) do
    case derive_subject_digest(domain_tag, subject, Keyword.take(opts, [:server, :timeout_ms])) do
      {:ok, %{digest: digest}} ->
        subject_digest = normalize_digest(envelope["subject_digest"])

        if subject_digest == {:ok, digest} do
          {:ok, {:verified, :engine_derived}}
        else
          {:refused,
           Refusal.new(:bad_field, "envelope subject_digest does not bind the engine-derived digest of subject", %{
             domain_tag: domain_tag,
             expected: Base.encode16(digest, case: :lower),
             envelope: inspect(envelope["subject_digest"], limit: 40)
           })}
        end

      {outcome, refusal} ->
        {outcome, refusal}
    end
  end

  defp binding_source({binding, source}), do: %{subject_binding: binding, subject_binding_source: source}

  defp normalize_digest(value) when is_binary(value) and byte_size(value) == 32, do: {:ok, value}

  defp normalize_digest(value) when is_binary(value) and byte_size(value) == 64 do
    case Base.decode16(value, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> :error
    end
  end

  defp normalize_digest(value) when is_list(value), do: byte_list(value, 32)
  defp normalize_digest(_), do: :error

  defp byte_list(bytes, width) when is_binary(bytes), do: byte_list(:binary.bin_to_list(bytes), width)

  defp byte_list(list, width) when is_list(list) do
    if length(list) == width and Enum.all?(list, &(&1 in 0..255)) do
      {:ok, :binary.list_to_bin(list)}
    else
      :error
    end
  end

  defp byte_list(_, _), do: :error

  # ---- engine-derived subject binding (ABI-gap closure, AG2r #2) -----------------------------

  @envelope_domain_tag "affidavit.crypto-trust-plane.v1"

  @doc """
  Derives a domain-separated subject digest through the engine's `derive_subject_digest` op.

  `domain_tag` must be a nonempty binary; `subject` is arbitrary bytes (or a hex string, which is
  passed through as raw bytes). The engine hashes `tag || 0x00 || tag || 0x00 || u64_be(len) ||
  subject` with BLAKE3 and returns both the digest and the exact pre-image, so the host can audit
  the domain separation without re-deriving the law. This closes the ABI gap the module doc names:
  the subject/payload-to-envelope binding becomes engine-derived, not caller-attested.

      {:ok, %{digest_hex: String.t(), pre_image_hex: String.t(), digest: binary()}}
      | {:refused | :trap | :unsupported, %AshAffidavit.Refusal{}}

  Reads `:server`/`:timeout_ms` options.
  """
  @spec derive_subject_digest(binary(), binary(), keyword()) ::
          {:ok, map()} | {:refused, Refusal.t()} | {:trap, Refusal.t()} | {:unsupported, Refusal.t()}
  def derive_subject_digest(domain_tag, subject, opts \\ []) when is_binary(domain_tag) and is_binary(subject) do
    cond do
      domain_tag == "" ->
        {:refused, Refusal.new(:bad_field, "domain_tag must not be empty")}

      true ->
        request = %{
          "op" => "derive_subject_digest",
          "domain_tag" => domain_tag,
          "subject_hex" => Base.encode16(subject, case: :lower)
        }

        case AshAffidavit.call(request, Keyword.take(opts, [:server, :timeout_ms])) do
          {:ok, %{"digest_hex" => digest_hex, "pre_image_hex" => pre_image_hex}} ->
            with {:ok, digest} <- Base.decode16(digest_hex, case: :lower) do
              {:ok, %{digest_hex: digest_hex, pre_image_hex: pre_image_hex, digest: digest}}
            end

          other ->
            other
        end
    end
  end

  @doc """
  Adjudicates one signature through the engine's `verify_signature` op, routed by algorithm.

  `key_source` is either an envelope document (its `"version"` is `#{@envelope_version}`; the
  algorithm comes from its `"algorithm"` field) or a key-material map (`"alg"`/`"algorithm"` plus
  `"public_key_hex"` or raw `"public_key"`). An envelope carries no key, so one must arrive as the
  `:public_key_hex`/`:public_key` option. `signature` and `signing_input` are raw bytes or hex
  strings. The engine answers per-alg (ES256 DER low-s, ES256K fixed 64-byte low-s over a
  compressed SEC1 key, Ed25519 strict) and never claims more than it checked.

      {:ok, %{valid: boolean(), refusal: :verification_failed | nil, alg: String.t()}}
      | {:refused | :trap | :unsupported, %AshAffidavit.Refusal{}}

  `valid: false` with `refusal: :verification_failed` is a decided-negative engine answer (a
  well-formed key/signature over the wrong bytes), not a refusal. Encoded-but-broken material
  (`malformed_public_key`/`malformed_signature`) maps to `{:refused, :bad_field}`; an algorithm
  outside the engine's set maps to `{:unsupported, :unknown_op}`. Reads `:server`/`:timeout_ms`.
  """
  @spec verify_signature(map(), binary(), binary(), keyword()) ::
          {:ok, map()} | {:refused, Refusal.t()} | {:trap, Refusal.t()} | {:unsupported, Refusal.t()}
  def verify_signature(key_source, signature, signing_input, opts \\ [])

  def verify_signature(key_source, _signature, _signing_input, _opts) when not is_map(key_source) do
    {:refused, Refusal.new(:missing_field, "key material must be a map")}
  end

  def verify_signature(key_source, signature, signing_input, opts) when is_map(key_source) do
    with {:ok, alg} <- algorithm_of(key_source, opts),
         {:ok, key_hex} <- key_hex_of(key_source, opts),
         {:ok, signature_hex} <- hex_arg(signature, "signature"),
         {:ok, input_hex} <- hex_arg(signing_input, "signing_input") do
      request = %{
        "op" => "verify_signature",
        "alg" => alg,
        "public_key_hex" => key_hex,
        "signature_hex" => signature_hex,
        "signing_input_hex" => input_hex
      }

      case AshAffidavit.call(request, Keyword.take(opts, [:server, :timeout_ms])) do
        {:ok, %{"valid" => valid, "refusal" => refusal}} ->
          adjudicate(valid, refusal, alg)

        other ->
          other
      end
    end
  end

  defp algorithm_of(key_source, opts) do
    cond do
      envelope?(key_source) and is_binary(key_source["algorithm"]) and key_source["algorithm"] != "" ->
        {:ok, key_source["algorithm"]}

      envelope?(key_source) ->
        {:refused, Refusal.new(:missing_field, "envelope carries no usable `algorithm` field")}

      true ->
        alg =
          key_source[:alg] || key_source["alg"] || key_source[:algorithm] || key_source["algorithm"] ||
            opts[:alg]

        if is_binary(alg) and alg != "" do
          {:ok, alg}
        else
          {:refused, Refusal.new(:missing_field, "key material carries no `alg`")}
        end
    end
  end

  defp envelope?(%{"version" => @envelope_version}), do: true
  defp envelope?(_), do: false

  defp key_hex_of(key_source, opts) do
    hex =
      key_source[:public_key_hex] || key_source["public_key_hex"] || opts[:public_key_hex]

    raw = key_source[:public_key] || key_source["public_key"] || opts[:public_key]

    cond do
      is_binary(hex) and hex != "" ->
        {:ok, hex}

      is_binary(raw) and raw != "" ->
        {:ok, Base.encode16(raw, case: :lower)}

      true ->
        {:refused, Refusal.new(:missing_field, "key material carries no public key")}
    end
  end

  # A raw-bytes-or-hex argument: an even-length decodable hex string passes through; anything
  # else is treated as raw bytes and hex-encoded. Raw bytes that happen to be valid hex text are
  # indistinguishable and are taken as hex — the wire form is unambiguous either way.
  defp hex_arg(value, _name) when is_binary(value) do
    if byte_size(value) > 0 and rem(byte_size(value), 2) == 0 and Base.decode16(value, case: :mixed) do
      {:ok, value}
    else
      {:ok, Base.encode16(value, case: :lower)}
    end
  end

  defp hex_arg(_, name), do: {:refused, Refusal.new(:bad_field, "#{name} must be raw bytes or a hex string")}

  defp adjudicate(true, _refusal, alg), do: {:ok, %{valid: true, refusal: nil, alg: alg}}

  defp adjudicate(false, "verification_failed", alg),
    do: {:ok, %{valid: false, refusal: :verification_failed, alg: alg}}

  defp adjudicate(false, "unsupported_algorithm" <> _rest, alg) do
    {:unsupported, Refusal.new(:unknown_op, "engine refuses the algorithm for this op", %{alg: alg})}
  end

  defp adjudicate(false, "malformed_" <> _rest = refusal, alg) do
    {:refused, Refusal.new(:bad_field, refusal, %{alg: alg})}
  end

  defp adjudicate(false, refusal, alg) do
    {:unsupported,
     Refusal.new(:engine_unclassified, "engine returned an unrecognized verify_signature refusal", %{
       refusal: refusal,
       alg: alg
     })}
  end

  # A binary digest in either wire form: `width` raw bytes or 2*width hex chars.
  defp digest_shape(value, width) when is_binary(value) do
    cond do
      byte_size(value) == width -> true
      byte_size(value) == 2 * width -> match?({:ok, _}, Base.decode16(value, case: :mixed))
      true -> false
    end
  end

  defp digest_shape(list, width) when is_list(list),
    do: match?({:ok, _}, byte_list(list, width))

  defp digest_shape(_, _), do: false
end
