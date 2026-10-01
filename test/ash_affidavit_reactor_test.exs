# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Reactor.Step) do
  defmodule AshAffidavit.ReactorTest do
    # Real Reactor runs the real step over the real pinned engine.
    use ExUnit.Case, async: false

    alias AshAffidavit.Reactor.Step
    alias AshAffidavit.Refusal

    defmodule Flow do
      @moduledoc false
      use Reactor

      input(:payload)
      input(:events)

      step :commit, {AshAffidavit.Reactor.Step, op: :commit} do
        argument :payload, input(:payload)
      end

      step :assemble, {AshAffidavit.Reactor.Step, op: :assemble} do
        argument :events, input(:events)
      end

      collect :both do
        argument :commit, result(:commit)
        argument :assemble, result(:assemble)
      end

      return :both
    end

    defmodule Failing do
      @moduledoc false
      use Reactor

      input(:events)

      step :assemble, {AshAffidavit.Reactor.Step, op: :assemble} do
        argument :events, input(:events)
      end

      return :assemble
    end

    setup_all do
      start_supervised!({AshAffidavit.Pool, size: 2})
      :ok
    end

    defp events do
      ex = "priv/affidavit/op-examples.json" |> File.read!() |> Jason.decode!()
      Enum.find(ex["examples"], &(&1["op"] == "assemble"))["request"]["events"]
    end

    test "a reactor runs engine ops and every result states authority NONE or none" do
      assert {:ok, %{commit: commit, assemble: assemble}} =
               Reactor.run(Flow, %{payload: "hello", events: events()}, %{}, async?: false)

      assert commit["op"] == "commit" and assemble["op"] == "assemble"
      assert commit["commitment"] =~ ~r/\A[0-9a-f]{64}\z/
      assert Enum.all?([commit, assemble], &(Map.get(&1, "authority") in [nil, "NONE"]))
    end

    test "a refused op fails the reactor and the refusal stays typed" do
      assert {:error, error} = Reactor.run(Failing, %{events: "nope"}, %{}, async?: false)
      assert inspect(error) =~ "bad_field"
    end

    test "run/3 maps outcomes: ok, refused, unsupported and a missing :op option" do
      assert {:ok, %{"op" => "commit"}} = Step.run(%{payload: "x"}, %{}, op: :commit)
      assert {:error, %Refusal{code: :missing_field}} = Step.run(%{}, %{}, op: :commit)
      assert {:error, %Refusal{code: :unknown_op, class: :unsupported}} = Step.run(%{}, %{}, op: "no_such_op")
      assert {:error, %Refusal{code: :host_not_started}} = Step.run(%{payload: "x"}, %{}, op: :commit, server: :nope)
      assert {:error, %Refusal{code: :missing_field}} = Step.run(%{}, %{}, [])
    end

    test "only a trap is retried" do
      assert Step.compensate(Refusal.new(:call_trapped), %{}, %{}, []) == :retry
      assert Step.compensate(Refusal.new(:bad_field), %{}, %{}, []) == :ok
      assert Step.compensate(Refusal.new(:unknown_op), %{}, %{}, []) == :ok
    end
  end
end
