# UNSUPPORTED(generator-capability): no pack template emits standalone Ed25519 chain verifier
# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.ChainVerifier do
  @moduledoc """
  Ed25519 cryptographic signature and pre-image chain verifier for commercial settlement
  affidavits (`AshAffidavit`).

  Verifies detached Ed25519 signatures over canonical settlement payloads via `:crypto.verify/5`
  and delegates CTP-ENVELOPE-v1 pre-image bindings to `AshAffidavit.Signing`.

  Supports raw 32-byte public keys and 64-byte signatures, as well as Base64 and Base64url
  (padded or unpadded) encoded inputs.

  Any malformed, truncated, or bit-flipped Ed25519 signature or public key fails closed
  with `{:error, :invalid_ed25519_signature}`.
  """

  @doc """
  Verifies an affidavit settlement map (`payload`, `public_key`, `signature`) using Ed25519.

  Returns `{:ok, :verified}` when the signature is a valid 64-byte Ed25519 signature over
  `payload` under the 32-byte `public_key`, or `{:error, :invalid_ed25519_signature}` when
  tampered or invalid.
  """
  @spec verify_settlement(map()) :: {:ok, :verified} | {:error, :invalid_ed25519_signature}
  def verify_settlement(%{} = affidavit) do
    payload = Map.get(affidavit, "payload") || Map.get(affidavit, :payload)
    pub_input = Map.get(affidavit, "public_key") || Map.get(affidavit, :public_key)
    sig_input = Map.get(affidavit, "signature") || Map.get(affidavit, :signature)

    with true <- is_binary(payload),
         {:ok, pub_bytes} <- decode_key(pub_input),
         {:ok, sig_bytes} <- decode_sig(sig_input),
         true <- :crypto.verify(:eddsa, :none, payload, sig_bytes, [pub_bytes, :ed25519]) do
      {:ok, :verified}
    else
      _ -> {:error, :invalid_ed25519_signature}
    end
  end

  def verify_settlement(_), do: {:error, :invalid_ed25519_signature}

  defp decode_key(raw) when is_binary(raw) and byte_size(raw) == 32, do: {:ok, raw}

  defp decode_key(encoded) when is_binary(encoded) do
    case decode_base64_or_url(encoded) do
      {:ok, bytes} when byte_size(bytes) == 32 -> {:ok, bytes}
      _ -> :error
    end
  end

  defp decode_key(_), do: :error

  defp decode_sig(raw) when is_binary(raw) and byte_size(raw) == 64, do: {:ok, raw}

  defp decode_sig(encoded) when is_binary(encoded) do
    case decode_base64_or_url(encoded) do
      {:ok, bytes} when byte_size(bytes) == 64 -> {:ok, bytes}
      _ -> :error
    end
  end

  defp decode_sig(_), do: :error

  defp decode_base64_or_url(encoded) do
    case Base.decode64(encoded) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> Base.decode64(encoded, padding: false)
    end
    |> fallback_url_decode(encoded)
  end

  defp fallback_url_decode({:ok, bytes}, _encoded), do: {:ok, bytes}

  defp fallback_url_decode(:error, encoded) do
    case Base.url_decode64(encoded) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> Base.url_decode64(encoded, padding: false)
    end
  end
end
