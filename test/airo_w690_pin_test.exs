defmodule AshAffidavit.AiroW690PinTest do
  @moduledoc """
  Lane W690 AIRo pin court — hardens the w637 structural court with identity pins.

  Chicago-style: real file reads and real module resolution only; no mocks.
  Pins the AIRo ontology by SHA-256 + byte size (ledger row w637/airo-wiring-ledger),
  resolves every `VIA`-cited path to a loadable Elixir module where possible, and
  asserts the airo: term usage is drawn from AIRo 1.0.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("..", __DIR__)
  @ttl_rel "ontology/airo_risk_description.ttl"
  @ttl_path Path.join(@repo_root, @ttl_rel)

  @expected_sha256 "71d4f706f5134fe5f572eb091e7fed00ba99539150911fba78f0ebb92ce79638"
  @expected_bytes 12_084

  # VIA-cited lib/ paths that must resolve to real, loadable modules.
  @via_modules %{
    "lib/ash_affidavit/engine_load.ex" => AshAffidavit.EngineLoad,
    "lib/ash_affidavit/wasm_config.ex" => AshAffidavit.WasmConfig,
    # Note: the module defined in abi.ex is AshAffidavit.ABI (upper-case ABI).
    "lib/ash_affidavit/abi.ex" => AshAffidavit.ABI,
    "lib/ash_affidavit/ops.ex" => AshAffidavit.Ops,
    "lib/ash_affidavit/signing.ex" => AshAffidavit.Signing,
    "lib/ash_affidavit/signing/keys.ex" => AshAffidavit.Signing.Keys,
    "lib/ash_affidavit/refusal.ex" => AshAffidavit.Refusal
  }

  test "AIRo ontology pins to exact SHA-256 and byte size (ledger identity)" do
    assert File.exists?(@ttl_path)
    content = File.read!(@ttl_path)
    assert byte_size(content) == @expected_bytes
    assert Base.encode16(:crypto.hash(:sha256, content), case: :lower) == @expected_sha256
  end

  test "every VIA-cited lib path resolves to a loadable module" do
    for {path, module} <- @via_modules do
      assert File.exists?(Path.join(@repo_root, path)), "cited path missing: #{path}"

      assert Code.ensure_loaded(module) == {:module, module},
             "cited path #{path} does not load as #{inspect(module)}"
    end
  end

  test "airo: vocabulary usage stays within AIRo 1.0 terms (w600 pin parity)" do
    content = File.read!(@ttl_path)

    known =
      ~w(AISystem AIComponent AIUser AILifecyclePhase Output Hazard Risk RiskSource
         Consequence Impact Stakeholder Likelihood Severity RiskControl
         hasPurpose hasComponent producesOutput hasAIUser hasLifecyclePhase
         hasRisk hasResidualRisk isRiskSourceFor hasConsequence hasImpact
         hasImpactOnStakeholder hasLikelihood hasSeverity hasRiskControl
         mitigatesRiskConcept detectsRiskConcept eliminatesRiskConcept)
      |> MapSet.new()

    used =
      Regex.scan(~r/airo:([A-Za-z]+)/, content)
      |> Enum.map(&Enum.at(&1, 1))
      |> MapSet.new()

    assert MapSet.difference(used, known) |> MapSet.to_list() == []
  end

  test "TTL self-citation matches this court's identity pins (drift tripwire)" do
    content = File.read!(@ttl_path)
    # Lane-provenance comment header and the w637: subject namespace.
    assert content =~ "lane W637, AIRo wiring wave"
    assert content =~ "w637:AffidavitCryptoTrustPlane a airo:AISystem"
    # The TTL delegates VIA-existence checks to the w637 structural court.
    assert content =~ "test/airo_risk_description_test.exs"
  end
end
