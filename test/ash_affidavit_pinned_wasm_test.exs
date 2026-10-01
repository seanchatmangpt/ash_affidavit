# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.PinnedWasmTest do
  use ExUnit.Case, async: true

  alias AshAffidavit.EngineLoad
  alias AshAffidavit.Refusal
  alias AshAffidavit.WasmConfig

  @wasm Path.expand("../priv/affidavit/affidavit.wasm", __DIR__)
  @manifest Path.expand("../priv/affidavit/MANIFEST.json", __DIR__)
  # Independent copy of the pin published by the engine repo (registry/ARTIFACTS.sha256).
  @engine_pin "5e721cc20d07193eee5d489077f4cb534f12c45f948e53247f79f38a5a7761f7"
  @engine_size 284_650

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  test "vendored wasm sha256 and size match MANIFEST.json and the engine's published pin" do
    manifest = @manifest |> File.read!() |> Jason.decode!()
    bytes = File.read!(@wasm)

    assert sha256(bytes) == manifest["artifact"]["sha256"]
    assert byte_size(bytes) == manifest["artifact"]["bytes"]
    assert manifest["artifact"]["sha256"] == @engine_pin
    assert manifest["artifact"]["bytes"] == @engine_size
    assert WasmConfig.pinned_sha256() == @engine_pin
  end

  test "the real module is admitted: pin, compile, import surface, required exports" do
    assert {:ok, admitted} = EngineLoad.admit(File.read!(@wasm))
    assert admitted.wasm_sha256 == @engine_pin
    assert Map.keys(admitted.imports) == ["wasi_snapshot_preview1"]

    assert admitted.imports["wasi_snapshot_preview1"] |> Map.keys() |> Enum.sort() ==
             ~w(environ_get environ_sizes_get fd_write proc_exit)

    for export <- EngineLoad.required_exports(), do: assert(Map.has_key?(admitted.exports, export))
    assert "af_abi_version" in EngineLoad.required_exports()
  end

  test "tampered bytes are refused with :wasm_digest_mismatch before compile" do
    original = File.read!(@wasm)

    # A flip inside the magic header would make the module uncompilable: seeing a digest refusal
    # (not :wasm_invalid) shows the pin is judged before any compile.
    <<first, rest::binary>> = original
    magic_flipped = <<Bitwise.bxor(first, 0xFF), rest::binary>>

    # A flip deep in the body leaves a plausible module.
    mid = div(byte_size(original), 2)
    <<head::binary-size(mid), b, tail::binary>> = original
    body_flipped = <<head::binary, Bitwise.bxor(b, 0x01), tail::binary>>

    for tampered <- [magic_flipped, body_flipped] do
      digest = sha256(tampered)
      refute digest == @engine_pin
      refute EngineLoad.cached?(digest)

      assert {:error, %Refusal{code: :wasm_digest_mismatch, class: :refused_identity, details: details}} =
               EngineLoad.admit(tampered)

      assert details == %{expected: @engine_pin, actual: digest}
      refute EngineLoad.cached?(digest), "a refused module must not enter the compiled cache"
    end
  end

  test "a host started on tampered bytes answers every call with the typed refusal" do
    original = File.read!(@wasm)
    <<first, rest::binary>> = original
    tampered = <<Bitwise.bxor(first, 0xFF), rest::binary>>

    {:ok, host} = AshAffidavit.Host.start_link(name: nil, bytes: tampered, retry_base_ms: 60_000)

    assert {:refused, %Refusal{code: :wasm_digest_mismatch}} =
             AshAffidavit.call(%{"op" => "capabilities"}, server: host)

    refute AshAffidavit.Host.available?(host)
  end
end
