# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a key/JWKS
# loading surface. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Signing.Keys do
  @moduledoc """
  Key-material loading helpers for the signing surface.

  Structural only: a JWKS document is decoded, each key is checked for the members the trust
  plane's key model requires, and the set is normalized to plain maps with string keys. **No
  cryptographic use is made of the material** — the pinned wasm ABI exposes no key-consuming op
  (see `AshAffidavit.Signing`); these helpers exist so the host can gate and route key material
  ahead of the op that will consume it (AG3 wasm build).

  Supported algorithm names follow the trust plane's `AlgorithmId` set plus the JOSE names of the
  same families: `ED25519`/`Ed25519`, `ES256`, `ES256K`, `ML_DSA65`, `SLH_DSA_SHA2_128s`, and the
  hybrid `HYBRID_ES256_ML_DSA65`. A key naming an algorithm outside the set is kept in the set but
  refused by `select/2`; a JWKS whose `keys` member is missing or ill-formed is a typed refusal.

  Each admitted key is also structurally validated against its algorithm's public-key shape law:
  Ed25519 `x` must decode (unpadded base64url) to 32 bytes; ES256/ES256K carry either JWK `x`+`y`
  (32 bytes each) or a SEC1 point in `sec1` (ES256: 65 bytes, 0x04 prefix; ES256K: 33 bytes,
  0x02/0x03 prefix — never both forms). The PQ/hybrid families are LENGTH-DYNAMIC pending the AG1
  envelope field set (TODO in the source). Material members must be unpadded base64url;
  padding or non-base64url bytes are an `:invalid_encoding` refusal.
  """

  alias AshAffidavit.Refusal

  @algorithms ~w(ED25519 Ed25519 ES256 ES256K ML_DSA65 SLH_DSA_SHA2_128s HYBRID_ES256_ML_DSA65)
  @key_types ~w(EC OKP AKP)

  @doc """
  Loads a JWKS document (a map with `"keys"`, or its JSON bytes) into a normalized key list.

  Returns `{:ok, keys}` with each key a string-keyed map carrying at least `kid`, `kty`, `alg`,
  plus whatever material members the document carried (`crv`/`x`/`y`, `n`/`e`, `k`). Keys missing
  `kid`, `kty` or `alg` are refused — the trust plane's key model has no anonymous keys.
  """
  @spec from_jwks(map() | binary(), keyword()) :: {:ok, [map()]} | {:error, Refusal.t()}
  def from_jwks(jwks, _opts \\ [])

  def from_jwks(jwks, _opts) when is_binary(jwks) do
    case Jason.decode(jwks) do
      {:ok, decoded} -> from_jwks(decoded)
      {:error, reason} -> {:error, Refusal.new(:invalid_json, "JWKS is not valid JSON: " <> Exception.message(reason))}
    end
  end

  def from_jwks(%{"keys" => keys}, _opts) when is_list(keys) do
    Enum.reduce_while(keys, {:ok, []}, fn key, {:ok, acc} ->
      with {:ok, normalized} <- normalize_key(key),
           :ok <- validate_structure(normalized) do
        {:cont, {:ok, [normalized | acc]}}
      else
        {:error, refusal} -> {:halt, {:error, refusal}}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      other -> other
    end
  end

  def from_jwks(%{"keys" => _}, _opts), do: {:error, Refusal.new(:bad_field, "JWKS `keys` must be an array")}
  def from_jwks(_, _opts), do: {:error, Refusal.new(:missing_field, "JWKS must carry a `keys` array")}

  @doc """
  Selects the key for `kid`. `keys` is the output of `from_jwks/2` (or any list of key maps).

  A `kid` outside the set, or a key whose `alg` is outside the closed algorithm set, is a typed
  refusal.
  """
  @spec select([map()], String.t()) :: {:ok, map()} | {:error, Refusal.t()}
  def select(keys, kid) when is_list(keys) and is_binary(kid) do
    matching = Enum.filter(keys, &(&1["kid"] == kid))

    case matching do
      [] ->
        {:error, Refusal.new(:bad_field, "no key for kid #{inspect(kid)}", %{kid: kid})}

      [key] ->
        if key["alg"] in @algorithms do
          {:ok, key}
        else
          {:error,
           Refusal.new(:bad_field, "key algorithm #{inspect(key["alg"])} is outside the closed algorithm set", %{
             kid: kid,
             alg: key["alg"],
             algorithms: @algorithms
           })}
        end

      _many ->
        {:error, Refusal.new(:bad_field, "duplicate keys for kid #{inspect(kid)}", %{kid: kid})}
    end
  end

  @doc "The closed algorithm-name set `select/2` admits."
  @spec algorithms() :: [String.t()]
  def algorithms, do: @algorithms

  defp normalize_key(%{"kid" => kid, "kty" => kty, "alg" => alg} = key)
       when is_binary(kid) and is_binary(kty) and is_binary(alg) do
    if kty in @key_types do
      {:ok, Map.take(key, ~w(kid kty alg crv x y sec1 n e k))}
    else
      {:error,
       Refusal.new(:bad_field, "JWKS key `kty` #{inspect(kty)} is outside the supported set", %{kid: kid, kty: kty})}
    end
  end

  defp normalize_key(key) when is_map(key) do
    {:error,
     Refusal.new(:missing_field, "JWKS key is missing a required member", %{
       missing: Enum.reject(~w(kid kty alg), &is_binary(key[&1]))
     })}
  end

  defp normalize_key(key),
    do: {:error, Refusal.new(:bad_field, "JWKS key must be an object", %{value: inspect(key, limit: 3)})}

  # -- per-algorithm structural validation -----------------------------------------------------
  #
  # The pinned wasm consumes no key material, so this is structural hardening only: every
  # length/prefix law below is the algorithm's public-key shape law, checked before any key is
  # routed to a consumer. Bignum families (ML_DSA65, SLH_DSA_SHA2_128s, HYBRID_ES256_ML_DSA65)
  # are LENGTH-DYNAMIC here: their laws come from the AG1 CertifiedReceiptEnvelope field set,
  # which is not discoverable in this tree at this SHA (no rendered envelope schema in lib/ or
  # docs/). TODO(AG1): pin their byte lengths when the envelope field set lands and enforce
  # them exactly like the classical families.

  @dialyzer {:nowarn_function, validate_structure: 1}

  @doc false
  @spec validate_structure(map()) :: :ok | {:error, Refusal.t()}
  def validate_structure(%{"alg" => alg} = key) do
    cond do
      alg in ~w(ED25519 Ed25519) -> validate_ed25519(key)
      alg == "ES256" -> validate_ec(key, 32, compressed?: false)
      alg == "ES256K" -> validate_ec(key, 32, compressed?: true)
      alg in ~w(ML_DSA65 SLH_DSA_SHA2_128s HYBRID_ES256_ML_DSA65) -> :ok
      true -> :ok
    end
  end

  # OKP: `x` is the raw 32-byte public key, 43 chars of unpadded base64url.
  defp validate_ed25519(%{"x" => x} = key) when is_binary(x) do
    with {:ok, raw} <- b64url(x, key, "x") do
      if byte_size(raw) == 32 do
        :ok
      else
        {:error,
         Refusal.new(:bad_field, "Ed25519 key `x` must decode to 32 bytes, got #{byte_size(raw)}", key_details(key))}
      end
    end
  end

  defp validate_ed25519(key),
    do: {:error, Refusal.new(:missing_field, "Ed25519 (OKP) key is missing the `x` member", key_details(key))}

  # EC families: JWK form is `x`+`y` (32 bytes each, P-256/secp256k1 coordinate size); raw form
  # is a SEC1 point in `sec1` — uncompressed 0x04||X||Y (65 bytes) for ES256, compressed
  # 0x02/0x03||X (33 bytes) for ES256K. A key carrying neither is refused; one carrying both
  # is refused (two sources of truth).
  defp validate_ec(%{"sec1" => sec1} = key, _xy_size, compressed?: compressed?) when is_binary(sec1) do
    if match?(%{"x" => _, "y" => _}, key) do
      {:error, Refusal.new(:bad_field, "EC key carries both `sec1` and JWK `x`/`y`", key_details(key))}
    else
      check_sec1(sec1, compressed?)
    end
  end

  defp validate_ec(%{"x" => x, "y" => y} = key, xy_size, _compressed?) when is_binary(x) and is_binary(y) do
    with {:ok, x_raw} <- b64url(x, key, "x"),
         {:ok, y_raw} <- b64url(y, key, "y") do
      if byte_size(x_raw) == xy_size and byte_size(y_raw) == xy_size do
        :ok
      else
        {:error, Refusal.new(:bad_field, "EC key `x`/`y` must decode to #{xy_size} bytes each", key_details(key))}
      end
    end
  end

  defp validate_ec(key, _xy, _compressed?),
    do: {:error, Refusal.new(:missing_field, "EC key carries neither `sec1` nor JWK `x`/`y`", key_details(key))}

  defp check_sec1(sec1, true) do
    if byte_size(sec1) == 33 and binary_part(sec1, 0, 1) in [<<0x02>>, <<0x03>>] do
      :ok
    else
      {:error, Refusal.new(:bad_field, "ES256K `sec1` must be 33 bytes prefixed 0x02 or 0x03", %{})}
    end
  end

  defp check_sec1(sec1, false) do
    if byte_size(sec1) == 65 and binary_part(sec1, 0, 1) == <<0x04>> do
      :ok
    else
      {:error, Refusal.new(:bad_field, "ES256 `sec1` must be 65 bytes with the 0x04 uncompressed prefix", %{})}
    end
  end

  defp b64url(value, key, member) do
    cond do
      String.contains?(value, ["=", "+", "/"]) ->
        {:error,
         Refusal.new(
           :invalid_encoding,
           "#{member} must be unpadded base64url",
           Map.put(key_details(key), member, value)
         )}

      true ->
        case Base.url_decode64(value, padding: false) do
          {:ok, raw} -> {:ok, raw}
          :error -> {:error, Refusal.new(:invalid_encoding, "#{member} is not valid base64url", key_details(key))}
        end
    end
  end

  defp key_details(key), do: Map.take(key, ~w(kid kty alg crv))
end
