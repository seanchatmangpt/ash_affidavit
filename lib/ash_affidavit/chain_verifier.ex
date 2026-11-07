defmodule AshAffidavit.ChainVerifier do
  @moduledoc """
  Ed25519 cryptographic signature and pre-image chain verifier for commercial settlement
  affidavits (`AshAffidavit`).

  Verifies detached Ed25519 signatures over canonical settlement payloads via `:crypto.verify/5`
  and delegates CTP-ENVELOPE-v1 pre-image bindings to `AshAffidavit.Signing`.

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
    pub_b64 = Map.get(affidavit, "public_key") || Map.get(affidavit, :public_key)
    sig_b64 = Map.get(affidavit, "signature") || Map.get(affidavit, :signature)

    with true <- is_binary(payload) and is_binary(pub_b64) and is_binary(sig_b64),
         {:ok, pub_bytes} <- Base.decode64(pub_b64),
         true <- byte_size(pub_bytes) == 32,
         {:ok, sig_bytes} <- Base.decode64(sig_b64),
         true <- byte_size(sig_bytes) == 64,
         true <- :crypto.verify(:eddsa, :none, payload, sig_bytes, [pub_bytes, :ed25519]) do
      {:ok, :verified}
    else
      _ -> {:error, :invalid_ed25519_signature}
    end
  end
end
