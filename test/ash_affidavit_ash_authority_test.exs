# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.AshAuthorityTest do
  # Authority ceiling NONE across the Ash surface. Real engine for every op; a response that states an
  # authority above NONE cannot be produced by the real engine, so that one path uses a hand-written
  # GenServer speaking the host request protocol (a simple fake of a collaborator that cannot be made to
  # misbehave in-process; the real Host is used everywhere else).
  use ExUnit.Case, async: false

  alias Ash.Changeset
  alias AshAffidavit.Calculation.Verdict
  alias AshAffidavit.Change.Receipt, as: ReceiptChange
  alias AshAffidavit.Error.Refused
  alias AshAffidavit.Notifier
  alias AshAffidavit.Refusal
  alias AshAffidavit.Test.Build
  alias AshAffidavit.Validation.Verified

  @examples Path.expand("../priv/affidavit/op-examples.json", __DIR__) |> File.read!() |> Jason.decode!()

  defmodule EscalatingEngine do
    @moduledoc false
    use GenServer

    def start_link(response), do: GenServer.start_link(__MODULE__, response)

    @impl true
    def init(response), do: {:ok, response}

    @impl true
    def handle_call({:request, _body, _op, _timeout}, _from, response), do: {:reply, {:ok, response}, response}
  end

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 2})
    :ok
  end

  defp engine(response), do: start_supervised!(%{id: make_ref(), start: {EscalatingEngine, :start_link, [response]}})

  defp changeset, do: Changeset.for_create(Build, :record, %{name: "x"})

  defp run(op, request, extra \\ []) do
    opts = [op: op, request: fn _ -> request end] ++ extra
    {:ok, opts} = ReceiptChange.init(opts)
    ReceiptChange.run(changeset(), opts)
  end

  defp authority_values(%{} = response) do
    [Map.get(response, "authority"), get_in(response, ["evidence", "authority"])]
  end

  describe "the real engine, every op, through Change.Receipt" do
    for ex <- @examples["examples"] do
      test "#{ex["op"]} stores evidence with authority NONE or none and never ALIVE" do
        ex = Enum.find(@examples["examples"], &(&1["op"] == unquote(ex["op"])))
        result = run(ex["op"], ex["request"])

        assert result.errors == []
        evidence = result.context[:affidavit]
        assert evidence["ok"] == true
        assert Enum.all?(authority_values(evidence), &(&1 in [nil, "NONE"]))
        refute Map.get(evidence, "standing") == "ALIVE"
      end
    end
  end

  describe "refused, trap and unsupported are never success" do
    test "a refused engine outcome fails the changeset and stores no evidence" do
      result = run("assemble", %{"events" => "nope"})
      assert [%Refused{} = error] = result.errors
      assert Refused.outcome(error) == :refused
      refute Map.has_key?(result.context, :affidavit)
    end

    test "an unsupported outcome (unknown op) fails the changeset and stores no evidence" do
      result = ReceiptChange.run(changeset(), op: "no_such_op", request: fn _ -> %{} end)
      assert [%Refused{} = error] = result.errors
      assert Refused.outcome(error) == :unsupported
      refute Map.has_key?(result.context, :affidavit)
    end

    test "a host failure (no such server) fails the changeset" do
      result = run("commit", %{"payload" => "x"}, server: :ash_affidavit_no_such_host)
      assert [%Refused{} = error] = result.errors
      assert Refused.outcome(error) == :refused
      assert Refused.code(error) == :host_not_started
      refute Map.has_key?(result.context, :affidavit)
    end

    test "the validation fails and the calculation reports refused for a missing host" do
      {:ok, %{"receipt" => receipt}} = assemble()
      opts = [attribute: :receipt, server: :ash_affidavit_no_such_host]

      assert {:error, field: :receipt, message: message} = Verified.validate(changeset_with(receipt), opts, %{})
      assert message =~ "refused"
      assert Verdict.calculate([%{receipt: receipt}], opts, %{}) == [:refused]
    end

    test "the trap class maps to the trap outcome and is not :ok" do
      assert Refusal.outcome(Refusal.new(:call_trapped)) == :trap
      assert Refusal.outcome(Refusal.new(:authority_escalation)) == :refused
    end
  end

  describe "a response stating an authority above NONE is refused, never success" do
    test "call/2 refuses a top-level authority above NONE" do
      pid = engine(%{"ok" => true, "op" => "commit", "authority" => "CONSTRUCT"})

      assert {:refused, %Refusal{code: :authority_escalation, class: :refused_authority}} =
               AshAffidavit.call(%{"op" => "commit", "payload" => "x"}, server: pid)
    end

    test "call/2 refuses an evidence authority above NONE" do
      pid = engine(%{"ok" => true, "op" => "x", "authority" => "NONE", "evidence" => %{"authority" => "SELECT"}})
      assert {:refused, %Refusal{code: :authority_escalation}} = AshAffidavit.call(%{"op" => "x"}, server: pid)
    end

    test "positive control: the same fake with authority NONE is :ok" do
      pid = engine(%{"ok" => true, "op" => "commit", "authority" => "NONE"})
      assert {:ok, %{"authority" => "NONE"}} = AshAffidavit.call(%{"op" => "commit", "payload" => "x"}, server: pid)
    end

    test "the change stores nothing and the action fails" do
      pid = engine(%{"ok" => true, "op" => "commit", "authority" => "OBSERVE"})
      result = run("commit", %{"payload" => "x"}, server: pid)
      assert [%Refused{} = error] = result.errors
      assert Refused.code(error) == :authority_escalation
      refute Map.has_key?(result.context, :affidavit)
    end

    test "the validation fails and the calculation reports refused" do
      {:ok, %{"receipt" => receipt}} = assemble()
      pid = engine(%{"ok" => true, "op" => "verify", "accepted" => true, "authority" => "EXECUTE"})
      opts = [attribute: :receipt, server: pid]

      assert {:error, field: :receipt, message: message} = Verified.validate(changeset_with(receipt), opts, %{})
      assert message =~ "authority_escalation"
      assert Verdict.calculate([%{receipt: receipt}], opts, %{}) == [:refused]
    end
  end

  describe "the notifier" do
    test "emits only evidence the change stored, and that evidence states NONE" do
      id = "ash-affidavit-authority-#{System.unique_integer([:positive])}"
      pid = self()

      :telemetry.attach(
        id,
        [:ash_affidavit, :notifier, :action],
        fn _e, _m, meta, _c -> send(pid, {:notified, meta}) end,
        nil
      )

      Build |> Changeset.for_create(:record, %{name: "n"}) |> Ash.create!()
      assert_receive {:notified, %{evidence: evidence}}
      assert Enum.all?(authority_values(evidence), &(&1 in [nil, "NONE"]))

      without = Changeset.set_context(changeset(), %{affidavit: nil})
      note = %Ash.Notifier.Notification{resource: Build, action: %{name: :record}, changeset: without}
      assert Notifier.notify(note) == :ok
      refute_receive {:notified, _}, 50
      :telemetry.detach(id)
    end
  end

  describe "the installer" do
    if Code.ensure_loaded?(Igniter.Test) do
      import Igniter.Test

      test "install adds no authority setting to any file it touches" do
        igniter = test_project() |> Igniter.compose_task("ash_affidavit.install", [])

        for path <- ["mix.exs", ".formatter.exs"] do
          refute igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content) |> String.downcase() =~
                   "authority"
        end
      end
    end

    test "no upgrade task exists, so no upgrade path can set authority" do
      refute Code.ensure_loaded?(Mix.Tasks.AshAffidavit.Upgrade)
    end
  end

  defp changeset_with(receipt),
    do: Changeset.for_create(Build, :keep, %{receipt: receipt}, skip_unknown_inputs: [:receipt])

  defp assemble do
    request = Enum.find(@examples["examples"], &(&1["op"] == "assemble"))["request"]
    AshAffidavit.call(request)
  end
end
