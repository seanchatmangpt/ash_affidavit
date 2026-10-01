# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.OpReplayTest do
  # Replays every entry of priv/affidavit/op-examples.json against the real wasm. The examples
  # carry requests only (schema wasi-json-abi.op-examples/1), so the expectation is the registry
  # contract: an ok envelope for the op whose keys include the registry's response_fields, plus
  # the semantic cross-checks below that need no oracle beyond the examples themselves.
  use ExUnit.Case, async: false

  @examples Path.expand("../priv/affidavit/op-examples.json", __DIR__) |> File.read!() |> Jason.decode!()
  @registry AshAffidavit.registry()

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 2})
    :ok
  end

  test "examples and registry describe the same ops and abi" do
    assert @examples["abi_version"] == @registry["abi_version"]
    assert Enum.map(@examples["examples"], & &1["op"]) |> Enum.sort() == Enum.sort(AshAffidavit.ops())
  end

  for {example, index} <- Enum.with_index(@examples["examples"]) do
    @example example
    test "example #{index} (#{example["op"]}) replays to an ok envelope with the registry's response fields" do
      op = @example["op"]
      assert {:ok, response} = AshAffidavit.call(@example["request"])
      assert response["ok"] == true
      assert response["op"] == op

      spec = Enum.find(@registry["ops"], &(&1["name"] == op))
      missing = spec["response_fields"] -- Map.keys(response)
      assert missing == [], "#{op}: response lacks registry response_fields #{inspect(missing)}"

      # request_fields are declared by the registry; the example may only use declared fields
      assert Map.keys(@example["request"]) -- spec["request_fields"] == []

      # determinism: the same request yields the byte-identical response
      assert {:ok, ^response} = AshAffidavit.call(@example["request"])
    end
  end

  test "assemble(example) reproduces the receipt the verify and mine examples carry, and verify accepts it" do
    by_op = Map.new(@examples["examples"], &{&1["op"], &1["request"]})
    assert {:ok, assembled} = AshAffidavit.call(by_op["assemble"])
    assert assembled["receipt"] == by_op["verify"]["receipt"]
    assert assembled["chain_hash"] == by_op["verify"]["receipt"]["chain_hash"]

    assert {:ok, verified} = AshAffidavit.call(%{"op" => "verify", "receipt" => assembled["receipt"]})
    assert verified["accepted"] == true

    assert {:ok, mined} = AshAffidavit.call(by_op["mine"])
    assert mined["all_accepted"] == true
  end

  test "capabilities reports the manifest abi_version and the registry's ops and error codes" do
    assert {:ok, caps} = AshAffidavit.capabilities()
    assert caps["abi_version"] == AshAffidavit.abi_version()
    assert Enum.sort(caps["ops"]) == Enum.sort(AshAffidavit.ops())
    assert Enum.sort(caps["error_codes"]) == Enum.sort(@registry["error_codes"])
  end
end
