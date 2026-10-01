# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.RefusalTest do
  use ExUnit.Case, async: false

  alias AshAffidavit.Refusal

  doctest AshAffidavit.Refusal

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 2})
    :ok
  end

  test "every engine error code in the registry maps to a closed, classified refusal" do
    for code <- AshAffidavit.registry()["error_codes"] do
      refusal = Refusal.from_engine(%{"code" => code, "message" => "m"})
      assert refusal.code == String.to_existing_atom(code)
      assert refusal.code in Refusal.codes()
      assert refusal.class in [:refused_input, :blocked_resource, :trap, :unsupported]
    end
  end

  test "an engine code outside the registry is :engine_unclassified (unsupported), carried verbatim" do
    refusal = Refusal.from_engine(%{"code" => "brand_new", "extra" => 1})
    assert {refusal.code, refusal.class, Refusal.outcome(refusal)} == {:engine_unclassified, :unsupported, :unsupported}
    assert refusal.raw == %{"code" => "brand_new", "extra" => 1}
  end

  test "the three outcomes stay distinct" do
    assert Refusal.outcome(Refusal.new(:bad_field)) == :refused
    assert Refusal.outcome(Refusal.new(:wasm_digest_mismatch)) == :refused
    assert Refusal.outcome(Refusal.new(:resource_limit)) == :refused
    assert Refusal.outcome(Refusal.new(:call_trapped)) == :trap
    assert Refusal.outcome(Refusal.new(:abi_failure)) == :trap
    assert Refusal.outcome(Refusal.new(:unknown_op)) == :unsupported
    assert_raise ArgumentError, fn -> Refusal.new(:not_a_code) end
  end

  test "real engine errors come back through call/2 as typed outcomes" do
    assert {:unsupported, %Refusal{code: :unknown_op}} = AshAffidavit.call(%{"op" => "no_such_op"})
    assert {:refused, %Refusal{code: :missing_field}} = AshAffidavit.call(%{})
    assert {:refused, %Refusal{code: :missing_field}} = AshAffidavit.call(%{"op" => "verify"})
    assert {:refused, %Refusal{code: :bad_field}} = AshAffidavit.call(%{"op" => "assemble", "events" => "nope"})

    deep = Enum.reduce(1..100, "x", fn _, acc -> [acc] end)

    assert {:refused, %Refusal{code: :too_deep, class: :blocked_resource, details: %{"limit" => "json_depth"}}} =
             AshAffidavit.call(%{"op" => "commit", "payload" => deep})
  end
end
