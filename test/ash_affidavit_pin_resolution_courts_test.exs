# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# Lane W10 (v26.10 wave): courts for the pinned-receipt/refusal surface that the existing suite
# left uncovered — pin resolution precedence, response decode edges, and the compiled-cache
# lifecycle. Real collaborators only: real files, real config state, real compiled engine.

defmodule AshAffidavit.PinResolutionCourtsTest do
  use ExUnit.Case, async: false

  alias AshAffidavit.ABI
  alias AshAffidavit.EngineLoad
  alias AshAffidavit.Refusal
  alias AshAffidavit.WasmConfig

  @wasm Path.expand("../priv/affidavit/affidavit.wasm", __DIR__)
  @pin "5e721cc20d07193eee5d489077f4cb534f12c45f948e53247f79f38a5a7761f7"

  # ---- court 1: pin resolution and limits precedence (fail-closed) -------------------------

  test "expected_sha256 honors an explicit pin and resolves :unpinned for a non-vendored path" do
    assert WasmConfig.expected_sha256(expected_sha256: @pin) == @pin

    scratch = Path.join(System.tmp_dir!(), "affidavit-court-#{System.unique_integer([:positive])}.wasm")
    File.write!(scratch, "not wasm")
    on_exit(fn -> File.rm(scratch) end)

    # A bytes source that is not the vendored engine has no pin: unpinned, never the vendored pin.
    assert WasmConfig.expected_sha256(wasm_path: scratch) == :unpinned
    # No opts at all: the vendored engine's published pin.
    assert WasmConfig.expected_sha256() == @pin
  end

  test "limits precedence: opts beat config, non-integer config falls back to the default, fuel derives from timeout" do
    default = WasmConfig.limits()
    assert default.fuel == default.timeout_ms * default.fuel_per_ms

    Application.put_env(:ash_affidavit, :timeout_ms, 123)
    Application.put_env(:ash_affidavit, :memory_limit_bytes, "bogus")

    on_exit(fn ->
      Application.delete_env(:ash_affidavit, :timeout_ms)
      Application.delete_env(:ash_affidavit, :memory_limit_bytes)
    end)

    limits = WasmConfig.limits()
    # valid config applies...
    assert limits.timeout_ms == 123
    # ...and a derived fuel follows it...
    assert limits.fuel == 123 * limits.fuel_per_ms
    # ...while an invalid (non-integer) config value falls back to the shipped default.
    assert limits.memory_limit_bytes == default.memory_limit_bytes

    overridden = WasmConfig.limits(timeout_ms: 456, memory_limit_bytes: 7)
    assert overridden.timeout_ms == 456
    assert overridden.memory_limit_bytes == 7
    assert overridden.fuel == 456 * overridden.fuel_per_ms
  end

  # ---- court 2: response decode edges on the pinned ABI ------------------------------------

  test "decode_response: non-object JSON is malformed_response, broken bytes are invalid_json with size" do
    assert {:error, %Refusal{code: :malformed_response, class: :trap}} =
             ABI.decode_response("[1, 2, 3]")

    assert {:error, %Refusal{code: :invalid_json, details: %{bytes: 8}}} =
             ABI.decode_response("not json")

    # An `ok: false` envelope is a successfully decoded body: classifying it is the caller's job.
    assert {:ok, %{"ok" => false, "error" => %{"code" => "too_large"}}} =
             ABI.decode_response(~s({"ok": false, "error": {"code": "too_large"}}))
  end

  # ---- court 3: the compiled-engine cache lifecycle on the real pinned bytes ---------------

  test "a successful admit populates the compiled cache and purge_cache evicts it" do
    EngineLoad.purge_cache()
    bytes = File.read!(@wasm)

    refute EngineLoad.cached?(@pin)

    assert {:ok, %{wasm_sha256: @pin}} = EngineLoad.admit(bytes)
    assert EngineLoad.cached?(@pin)

    # The cached entry is live: admitting the same bytes again returns the same compiled module.
    assert {:ok, %{engine: engine}} = EngineLoad.admit(bytes)
    assert is_struct(engine)

    assert :ok = EngineLoad.purge_cache()
    refute EngineLoad.cached?(@pin), "purge must evict the pinned module"

    # And the boundary still admits after eviction.
    assert {:ok, %{}} = EngineLoad.admit(bytes)
    assert EngineLoad.cached?(@pin)
    EngineLoad.purge_cache()
  end
end
