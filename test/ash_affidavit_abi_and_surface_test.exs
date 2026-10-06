# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.AbiAndSurfaceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias AshAffidavit.EngineLoad
  alias AshAffidavit.Refusal
  alias AshAffidavit.WasmConfig
  alias Mix.Tasks.AshAffidavit.Vendor
  alias Mix.Tasks.AshAffidavit.Verify

  @wasm Path.expand("../priv/affidavit/affidavit.wasm", __DIR__)

  # ---- hand-assembled WebAssembly (no toolchain) --------------------------------------------

  defp s(b), do: <<byte_size(b)>> <> b
  defp sec(id, payload), do: <<id, byte_size(payload)>> <> payload

  # A tiny valid module exporting memory, af_alloc, af_free, af_call, af_abi_version and
  # importing exactly `{module, name}` as a function of type (i32 i32 i32) -> i32.
  defp module_importing(import_module, import_name) do
    types =
      <<5, 0x60, 3, 0x7F, 0x7F, 0x7F, 1, 0x7F, 0x60, 1, 0x7F, 1, 0x7F, 0x60, 2, 0x7F, 0x7F, 0, 0x60, 2, 0x7F, 0x7F, 1,
        0x7E, 0x60, 0, 1, 0x7F>>

    imports = <<1>> <> s(import_module) <> s(import_name) <> <<0, 0>>
    funcs = <<4, 1, 2, 3, 4>>

    exports =
      <<5>> <>
        s("memory") <>
        <<2, 0>> <>
        s("af_alloc") <>
        <<0, 1>> <>
        s("af_free") <>
        <<0, 2>> <>
        s("af_call") <>
        <<0, 3>> <>
        s("af_abi_version") <>
        <<0, 4>>

    code = <<4, 4, 0, 0x41, 0, 0x0B, 2, 0, 0x0B, 4, 0, 0x42, 0, 0x0B, 4, 0, 0x41, 1, 0x0B>>

    <<0, "asm", 1, 0, 0, 0>> <>
      sec(1, types) <>
      sec(2, imports) <> sec(3, funcs) <> sec(5, <<1, 0, 1>>) <> sec(7, exports) <> sec(10, code)
  end

  test "a WASI import outside the allowlist is refused with :wasm_import_surface_mismatch" do
    bytes = module_importing("wasi_snapshot_preview1", "sock_accept")

    assert {:error, %Refusal{code: :wasm_import_surface_mismatch, class: :refused_identity, details: details}} =
             EngineLoad.admit(bytes, expected_sha256: :unpinned)

    assert details.unexpected_functions == ["wasi_snapshot_preview1.sock_accept"]
    assert details.unexpected == []
    assert "fd_write" in details.allowed_functions
  end

  test "an import from a foreign module is refused too" do
    bytes = module_importing("env", "host_secret")

    assert {:error, %Refusal{code: :wasm_import_surface_mismatch, details: details}} =
             EngineLoad.admit(bytes, expected_sha256: :unpinned)

    assert details.unexpected == ["env"]
  end

  test "a refused module is never cached and never reaches a host" do
    bytes = module_importing("wasi_snapshot_preview1", "sock_accept")
    digest = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    assert {:error, _} = EngineLoad.admit(bytes, expected_sha256: :unpinned)
    refute EngineLoad.cached?(digest)
  end

  test "a module missing a required export is refused with :wasm_missing_export" do
    # same module but without af_abi_version: build it by hand
    types = <<3, 0x60, 1, 0x7F, 1, 0x7F, 0x60, 2, 0x7F, 0x7F, 0, 0x60, 2, 0x7F, 0x7F, 1, 0x7E>>
    funcs = <<3, 0, 1, 2>>

    exports =
      <<4>> <>
        s("memory") <> <<2, 0>> <> s("af_alloc") <> <<0, 0>> <> s("af_free") <> <<0, 1>> <> s("af_call") <> <<0, 2>>

    code = <<3, 4, 0, 0x41, 0, 0x0B, 2, 0, 0x0B, 4, 0, 0x42, 0, 0x0B>>

    bytes =
      <<0, "asm", 1, 0, 0, 0>> <>
        sec(1, types) <> sec(3, funcs) <> sec(5, <<1, 0, 1>>) <> sec(7, exports) <> sec(10, code)

    assert {:error, %Refusal{code: :wasm_missing_export, details: %{missing: ["af_abi_version"]}}} =
             EngineLoad.admit(bytes, expected_sha256: :unpinned)
  end

  test "af_abi_version exported by the real module equals the manifest abi_version" do
    manifest = WasmConfig.manifest() |> elem(1)
    assert {:ok, admitted} = EngineLoad.admit(File.read!(@wasm))

    {:ok, store} = Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{}, %Wasmex.StoreLimits{}, admitted.engine)
    :ok = Wasmex.StoreOrCaller.set_fuel(store, 1_000_000_000)
    {:ok, pid} = Wasmex.start_link(%{store: store, module: admitted.module})

    assert {:ok, [version]} = Wasmex.call_function(pid, "af_abi_version", [])
    assert version == manifest["abi_version"]
    assert version == AshAffidavit.abi_version()
  end

  test "the capabilities probe agrees with af_abi_version and the manifest" do
    start_supervised!({AshAffidavit.Pool, size: 1})
    assert {:ok, %{"abi_version" => abi}} = AshAffidavit.capabilities()
    assert abi == WasmConfig.manifest() |> elem(1) |> Map.fetch!("abi_version")
  end

  test "mix ash_affidavit.verify and --check pass on the vendored engine" do
    out = capture_io(fn -> Verify.run([]) end)
    assert out =~ "Affidavit engine VERIFIED (abi_version 1)"

    out = capture_io(fn -> Vendor.run(["--check"]) end)
    assert out =~ "affidavit.wasm OK sha256=5cc37aea"
  end

  test "the contract's typed imports equal the manifest's imports and the real module's imports" do
    contract = File.read!(Path.expand("../ontology/affidavit-contract.ttl", __DIR__))

    contract_imports =
      ~r/qri:importName "([a-z_]+)" ; qri:importParams "([a-z0-9,]*)" ; qri:importResults "([a-z0-9,]*)"/
      |> Regex.scan(contract, capture: :all_but_first)
      |> Enum.map(fn [name, params, results] -> {name, split_types(params), split_types(results)} end)
      |> Enum.sort()

    {:ok, manifest} = WasmConfig.manifest()

    manifest_imports =
      manifest["host_abi"]["imports"]
      |> Enum.map(&{&1["name"], &1["params"], &1["results"]})
      |> Enum.sort()

    {:ok, admitted} = EngineLoad.admit(File.read!(@wasm))

    module_imports =
      for {name, {:fn, params, results}} <- admitted.imports["wasi_snapshot_preview1"] do
        {name, Enum.map(params, &Atom.to_string/1), Enum.map(results, &Atom.to_string/1)}
      end
      |> Enum.sort()

    assert length(contract_imports) == 5
    assert contract_imports == manifest_imports
    assert contract_imports == module_imports

    contract_exports =
      ~r/qri:requiredExport ([^;]+);/
      |> Regex.run(contract, capture: :all_but_first)
      |> hd()
      |> then(&Regex.scan(~r/"([a-z_]+)"/, &1, capture: :all_but_first))
      |> List.flatten()
      |> Enum.sort()

    assert contract_exports == Enum.sort(manifest["host_abi"]["exports"])
    assert contract_exports == Enum.sort(EngineLoad.required_exports())
  end

  defp split_types(""), do: []
  defp split_types(types), do: String.split(types, ",")
end
