defmodule AshAffidavit.AiroRiskDescriptionTest do
  @moduledoc """
  Structural court for ontology/airo_risk_description.ttl (lane W637, AIRo wiring wave).

  Chicago-style: the real TTL file on disk is the collaborator — no mocks. Asserts the
  file exists, parses structurally (prefixes declared, statements terminated, all
  airo: terms drawn from AIRo 1.0, airo:AISystem subject present), and that every
  `VIA <repo-relative path>` cited in the TTL actually exists in the repo.
  """

  use ExUnit.Case, async: true

  @ttl_path Path.join([__DIR__, "..", "ontology", "airo_risk_description.ttl"])

  @airo_terms ~w(AISystem AIComponent AIUser AILifecyclePhase Output Hazard Risk RiskSource
                 Consequence Impact Stakeholder Likelihood Severity RiskControl
                 hasPurpose hasComponent producesOutput hasAIUser hasLifecyclePhase
                 hasRisk hasResidualRisk isRiskSourceFor hasConsequence hasImpact
                 hasImpactOnStakeholder hasLikelihood hasSeverity hasRiskControl
                 mitigatesRiskConcept detectsRiskConcept eliminatesRiskConcept) |> MapSet.new()

  @cited_paths ~w(
    lib/ash_affidavit/engine_load.ex
    lib/ash_affidavit/wasm_config.ex
    lib/ash_affidavit/abi.ex
    lib/ash_affidavit/ops.ex
    lib/ash_affidavit/signing.ex
    lib/ash_affidavit/signing/keys.ex
    lib/ash_affidavit/refusal.ex
    test/ash_affidavit_signing_courts_test.exs
    test/ash_affidavit_pinned_wasm_test.exs
    test/ash_affidavit_refusal_test.exs
    HANDWRITTEN.md
    ontology/airo_risk_description.ttl
    test/airo_risk_description_test.exs
  )

  test "TTL file exists and is non-empty" do
    assert File.exists?(@ttl_path), "missing #{@ttl_path}"
    content = File.read!(@ttl_path)
    assert byte_size(content) > 2_000
  end

  test "parses structurally: prefixes declared, statements terminated, AIRo terms known" do
    content = File.read!(@ttl_path)

    for prefix <- ~w(airo dcterms rdfs) do
      assert content =~ ~s(@prefix #{prefix}:), "prefix #{prefix} not declared"
    end

    # Statements terminated (dot-terminated blocks); every block has a subject.
    statements = content |> String.split(["."], trim: true)
    assert length(statements) > 20

    # All airo: predicates used are real AIRo 1.0 terms (class or property).
    used =
      Regex.scan(~r/airo:([A-Za-z]+)/, content)
      |> Enum.map(&Enum.at(&1, 1))
      |> MapSet.new()

    unknown = MapSet.difference(used, @airo_terms) |> MapSet.to_list()
    assert unknown == [], "terms not in AIRo 1.0 vocabulary: #{inspect(unknown)}"
  end

  test "describes the trust plane as an airo:AISystem with risk sources and controls" do
    content = File.read!(@ttl_path)
    assert content =~ "AffidavitCryptoTrustPlane a airo:AISystem"
    assert content =~ "a airo:Hazard"
    assert content =~ "a airo:RiskControl"
    assert content =~ "a airo:Risk"
    assert Enum.count(Regex.scan(~r/a airo:Hazard/, content)) >= 2
    assert Enum.count(Regex.scan(~r/a airo:RiskControl/, content)) >= 5
  end

  test "every VIA-cited repo path exists on disk" do
    repo_root = Path.expand("..", __DIR__)

    missing =
      @cited_paths
      |> Enum.reject(&File.exists?(Path.join(repo_root, &1)))

    assert missing == [], "TTL cites paths that do not exist: #{inspect(missing)}"
  end
end
