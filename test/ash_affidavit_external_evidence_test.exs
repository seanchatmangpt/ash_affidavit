# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.ExternalEvidenceTest do
  # The two external-evidence ops (AuthZEN decision, SPIFFE/SVID identity) run against the real
  # vendored wasm. Both certify evidence only: authority NONE, consequence EVIDENCE_ONLY.
  use ExUnit.Case, async: false

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 1})
    :ok
  end

  test "both ops are in the engine's registry" do
    ops = AshAffidavit.ops()
    assert "certify_authzen_evidence" in ops
    assert "certify_spiffe_evidence" in ops
  end

  test "an AuthZEN decision is certified as evidence with no authority" do
    assert {:ok, r} =
             AshAffidavit.call(%{
               "op" => "certify_authzen_evidence",
               "request" => %{
                 "subject" => %{"type" => "user", "id" => "alice@example.com"},
                 "resource" => %{"type" => "account", "id" => "123"},
                 "action" => %{"name" => "can_read"}
               },
               "decision" => true,
               "policy_decision_point" => "https://pdp.example.com",
               "expected_policy_decision_point" => "https://pdp.example.com",
               "expected_principal" => "alice@example.com",
               "expected_effect_digest" => "123"
             })

    assert r["certified"] == true
    assert r["authority"] == "NONE"
    assert r["consequence"] == "EVIDENCE_ONLY"
    assert r["action"] == "can_read"
  end

  test "a SPIFFE x509 SVID is certified; a jwt SVID is refused, not certified" do
    base = %{
      "op" => "certify_spiffe_evidence",
      "spiffe_id" => "spiffe://prod.acme.com/billing/api",
      "expected_spiffe_id" => "spiffe://prod.acme.com/billing/api",
      "expected_trust_domain" => "prod.acme.com",
      "bundle_digest" => "sha256:canonical-example-bundle",
      "verified" => true
    }

    assert {:ok, r} = AshAffidavit.call(Map.put(base, "svid_type", "x509"))
    assert r["certified"] == true
    assert r["trust_domain"] == "prod.acme.com"
    assert r["path"] == "/billing/api"
    assert r["authority"] == "NONE"

    refusal = AshAffidavit.call(Map.put(base, "svid_type", "jwt"))
    refute match?({:ok, _}, refusal)
    assert inspect(refusal) =~ "jwt_not_admitted"
  end
end
