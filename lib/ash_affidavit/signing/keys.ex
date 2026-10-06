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
      case normalize_key(key) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
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
      {:ok, Map.take(key, ~w(kid kty alg crv x y n e k))}
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
end
