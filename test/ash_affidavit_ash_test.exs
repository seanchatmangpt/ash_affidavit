# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.AshTest do
  # Chicago style: the real pinned engine behind a real pool and a real ETS-backed Ash resource.
  use ExUnit.Case, async: false

  alias Ash.Changeset
  alias AshAffidavit.Calculation.Verdict
  alias AshAffidavit.Error.Refused
  alias AshAffidavit.Resource.Info
  alias AshAffidavit.Test.Build

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 2})
    :ok
  end

  describe "Info" do
    test "reads the declared runtime and operations" do
      assert Info.compiled?(Build)
      assert %{timeout_ms: 5_000, singleton: true} = Info.runtime(Build)
      assert Enum.map(Info.operations(Build), & &1.name) == ["commit", "verify"]
      assert Info.compiled!(Build).runtime.timeout_ms == 5_000
    end

    test "a module without the extension has no declaration" do
      refute Info.compiled?(AshAffidavit)
      assert Info.runtime(AshAffidavit) == nil
      assert Info.operations(AshAffidavit) == []
      assert_raise ArgumentError, fn -> Info.compiled!(AshAffidavit) end
    end
  end

  describe "AshAffidavit.Change.Receipt" do
    test "a successful action carries the engine evidence" do
      handler = attach_telemetry()
      record = Build |> Changeset.for_create(:record, %{name: "hello"}) |> Ash.create!()

      expected = AshAffidavit.call(%{"op" => "commit", "payload" => "hello"})
      assert {:ok, direct} = expected
      assert %{"ok" => true, "op" => "commit", "commitment" => commitment} = record.__metadata__.affidavit
      assert commitment == direct["commitment"]
      assert commitment =~ ~r/\A[0-9a-f]{64}\z/

      assert_receive {:telemetry, %{duration: duration}, %{op: "commit", outcome: :ok, code: nil}}
      assert is_integer(duration)
      :telemetry.detach(handler)
    end

    test "a typed refusal surfaces as an Ash error and keeps its code" do
      handler = attach_telemetry()

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Build |> Changeset.for_create(:record_bad, %{name: "x"}) |> Ash.create()

      assert [%Refused{refusal: refusal} = error] = errors
      assert refusal.code == :missing_field
      assert Refused.code(error) == :missing_field
      assert Refused.outcome(error) == :refused
      assert Exception.message(error) =~ "missing_field"

      assert_receive {:telemetry, _m, %{op: "commit", outcome: :refused, code: :missing_field}}
      :telemetry.detach(handler)
    end

    test "bulk_update strategy :atomic is refused and :stream runs the op per record" do
      records =
        for name <- ["a", "b"], do: Build |> Changeset.for_create(:record, %{name: name}) |> Ash.create!()

      atomic = Ash.bulk_update(records, :touch, %{name: "z"}, strategy: :atomic, return_errors?: true)
      refute atomic.status == :success
      assert inspect(atomic.errors) =~ "WASM call"

      stream =
        Ash.bulk_update(records, :touch, %{name: "z"},
          strategy: :stream,
          return_records?: true,
          return_errors?: true
        )

      assert stream.status == :success
      assert length(stream.records) == 2
      assert Enum.all?(stream.records, &(&1.__metadata__.affidavit["op"] == "commit"))
    end

    test "the notifier emits the evidence after the action" do
      id = "ash-affidavit-notifier-#{System.unique_integer([:positive])}"
      pid = self()

      :telemetry.attach(
        id,
        [:ash_affidavit, :notifier, :action],
        fn _event, measurements, metadata, _config -> send(pid, {:notified, measurements, metadata}) end,
        nil
      )

      Build |> Changeset.for_create(:record, %{name: "note"}) |> Ash.create!()

      assert_receive {:notified, %{count: 1}, %{resource: Build, action: :record, evidence: %{"op" => "commit"}}}
      :telemetry.detach(id)
    end

    test "init/1 refuses an unknown op, an unknown key and a bad phase" do
      alias AshAffidavit.Change.Receipt
      assert {:ok, opts} = Receipt.init(op: :verify)
      assert opts[:op] == "verify"
      assert {:error, "unknown op" <> _} = Receipt.init(op: :nope)
      assert {:error, "unknown options" <> _} = Receipt.init(op: :commit, bogus: 1)
      assert {:error, "`:phase`" <> _} = Receipt.init(op: :commit, phase: :later)
      assert {:error, "`:timeout`" <> _} = Receipt.init(op: :commit, timeout: 0)
      assert {:error, "`:op` is required" <> _} = Receipt.init([])
    end

    test "atomic/3 is not atomic" do
      assert {:not_atomic, _} = AshAffidavit.Change.Receipt.atomic(nil, [], nil)
    end
  end

  describe "validation, calculation and types" do
    setup do
      {:ok, %{"receipt" => receipt}} = assemble()
      %{receipt: receipt}
    end

    test "Verified accepts an engine-assembled receipt", %{receipt: receipt} do
      assert {:ok, record} = Build |> Changeset.for_create(:keep, %{receipt: receipt}) |> Ash.create()
      assert record.receipt == receipt
    end

    test "Verified rejects a tampered receipt", %{receipt: receipt} do
      tampered = Map.put(receipt, "chain_hash", String.duplicate("0", 64))

      assert {:error, %Ash.Error.Invalid{}} =
               Build |> Changeset.for_create(:keep, %{receipt: tampered}) |> Ash.create()
    end

    test "Verdict calculates accept and reject", %{receipt: receipt} do
      good = Build |> Changeset.for_create(:keep, %{receipt: receipt}) |> Ash.create!()
      assert Ash.load!(good, :verdict).verdict == :accept

      bad = %{good | receipt: Map.put(receipt, "chain_hash", String.duplicate("0", 64))}
      assert Verdict.calculate([bad], [attribute: :receipt], %{}) == [:reject]
      assert Verdict.calculate([%{good | receipt: nil}], [attribute: :receipt], %{}) == [nil]
    end

    test "the Receipt type shape-checks and the ChainHash type normalizes" do
      assert {:ok, nil} = Ash.Type.cast_input(AshAffidavit.Type.Receipt, nil, [])
      assert {:error, _} = Ash.Type.cast_input(AshAffidavit.Type.Receipt, %{"x" => 1}, [])

      upper = String.duplicate("AB", 32)
      assert {:ok, lower} = Ash.Type.cast_input(AshAffidavit.Type.ChainHash, upper, [])
      assert lower == String.downcase(upper)
      assert {:error, _} = Ash.Type.cast_input(AshAffidavit.Type.ChainHash, "short", [])
      assert {:error, _} = Ash.Type.cast_input(AshAffidavit.Type.ChainHash, 5, [])
    end
  end

  defp assemble do
    ex = AshAffidavit.registry() && "priv/affidavit/op-examples.json" |> File.read!() |> Jason.decode!()
    request = Enum.find(ex["examples"], &(&1["op"] == "assemble"))["request"]
    AshAffidavit.call(request)
  end

  defp attach_telemetry do
    id = "ash-affidavit-test-#{System.unique_integer([:positive])}"
    pid = self()

    :telemetry.attach(
      id,
      [:ash_affidavit, :op, :stop],
      fn _event, measurements, metadata, _config -> send(pid, {:telemetry, measurements, metadata}) end,
      nil
    )

    id
  end
end
