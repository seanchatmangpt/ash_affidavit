# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.ChainVerifierTest do
  use ExUnit.Case, async: true
  import Bitwise, only: [bxor: 2]

  alias AshAffidavit.ChainVerifier

  doctest ChainVerifier

  # RFC 8032 Test Vector 1: empty message
  @tv1_msg ""
  @tv1_pub Base.decode16!("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", case: :lower)
  @tv1_sig Base.decode16!(
             "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b",
             case: :lower
           )

  # RFC 8032 Test Vector 2: single byte message (0x72), in-tree KAT fixture
  @tv2_msg <<0x72>>
  @tv2_pub Base.decode16!("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c", case: :lower)
  @tv2_sig Base.decode16!(
             "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00",
             case: :lower
           )

  # RFC 8032 seeded settlement payload
  @tv3_msg "commercial-settlement-affidavit-tx-9941"
  @tv3_pub Base.decode16!("dd3c7dcb0215389e11290107ad28ba60a7bb47562f3cb4cc556628deadb6fce3", case: :lower)
  @tv3_sig Base.decode16!(
             "8790b418ae0af88043e65ea4da80efa4ba8e9fb8ad9e0c2e3f7d5dcf0e07f1fbf45848da9c7f35ce7f5d9945e6849b9bf3e2f5cd195cafdd4f5a4e2f13cd3900",
             case: :lower
           )

  describe "RFC 8032 test vectors with raw binary" do
    test "verifies vector 1 (empty payload)" do
      affidavit = %{
        payload: @tv1_msg,
        public_key: @tv1_pub,
        signature: @tv1_sig
      }

      assert {:ok, :verified} = ChainVerifier.verify_settlement(affidavit)
    end

    test "verifies vector 2 (single byte payload)" do
      affidavit = %{
        "payload" => @tv2_msg,
        "public_key" => @tv2_pub,
        "signature" => @tv2_sig
      }

      assert {:ok, :verified} = ChainVerifier.verify_settlement(affidavit)
    end

    test "verifies vector 3 (multi-byte commercial settlement payload)" do
      affidavit = %{
        payload: @tv3_msg,
        public_key: @tv3_pub,
        signature: @tv3_sig
      }

      assert {:ok, :verified} = ChainVerifier.verify_settlement(affidavit)
    end
  end

  describe "Base64 and Base64url encodings" do
    test "verifies standard Base64 encoded public key and signature" do
      affidavit = %{
        "payload" => @tv2_msg,
        "public_key" => Base.encode64(@tv2_pub),
        "signature" => Base.encode64(@tv2_sig)
      }

      assert {:ok, :verified} = ChainVerifier.verify_settlement(affidavit)
    end

    test "verifies unpadded Base64url encoded public key and signature" do
      affidavit = %{
        payload: @tv2_msg,
        public_key: Base.url_encode64(@tv2_pub, padding: false),
        signature: Base.url_encode64(@tv2_sig, padding: false)
      }

      assert {:ok, :verified} = ChainVerifier.verify_settlement(affidavit)
    end

    test "verifies padded Base64url encoded public key and signature" do
      affidavit = %{
        payload: @tv2_msg,
        public_key: Base.url_encode64(@tv2_pub, padding: true),
        signature: Base.url_encode64(@tv2_sig, padding: true)
      }

      assert {:ok, :verified} = ChainVerifier.verify_settlement(affidavit)
    end
  end

  describe "tamper resistance and negative invalidations" do
    test "fails on tampered/flipped signature byte" do
      <<first_byte, rest::binary>> = @tv2_sig
      corrupted_sig = <<bxor(first_byte, 0x01), rest::binary>>

      affidavit = %{
        payload: @tv2_msg,
        public_key: @tv2_pub,
        signature: corrupted_sig
      }

      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(affidavit)
    end

    test "fails on truncated signature" do
      truncated_sig = binary_part(@tv2_sig, 0, 63)

      affidavit = %{
        payload: @tv2_msg,
        public_key: @tv2_pub,
        signature: truncated_sig
      }

      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(affidavit)
    end

    test "fails on truncated public key" do
      truncated_pub = binary_part(@tv2_pub, 0, 31)

      affidavit = %{
        payload: @tv2_msg,
        public_key: truncated_pub,
        signature: @tv2_sig
      }

      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(affidavit)
    end

    test "fails on tampered payload" do
      affidavit = %{
        payload: "tampered payload",
        public_key: @tv2_pub,
        signature: @tv2_sig
      }

      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(affidavit)
    end

    test "fails on mismatched public key" do
      affidavit = %{
        payload: @tv2_msg,
        public_key: @tv1_pub,
        signature: @tv2_sig
      }

      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(affidavit)
    end

    test "fails on missing payload or non-binary payload" do
      assert {:error, :invalid_ed25519_signature} =
               ChainVerifier.verify_settlement(%{public_key: @tv2_pub, signature: @tv2_sig})

      assert {:error, :invalid_ed25519_signature} =
               ChainVerifier.verify_settlement(%{payload: 12_345, public_key: @tv2_pub, signature: @tv2_sig})
    end

    test "fails on non-map input" do
      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement("not a map")
      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(nil)
    end

    test "fails on malformed base64 strings" do
      affidavit = %{
        payload: @tv2_msg,
        public_key: "!!!not base64!!!",
        signature: @tv2_sig
      }

      assert {:error, :invalid_ed25519_signature} = ChainVerifier.verify_settlement(affidavit)
    end
  end
end
