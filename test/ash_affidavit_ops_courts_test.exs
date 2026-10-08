# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# Lane EA60 (v26.10.5 wave): courts for the typed op wrappers in AshAffidavit.Ops. Chicago
# discipline: the court asserts on the real built request structure against the engine
# repository's own rendered op-examples registry (priv/affidavit/op-examples.json) — no wasm
# execution is needed because the builders are pure; the generic call path over the same request
# shape is already courted by test/ash_affidavit_op_replay_test.exs against the real engine.

defmodule AshAffidavit.OpsCourtsTest do
  use ExUnit.Case, async: true

  alias AshAffidavit.Ops

  @examples "../priv/affidavit/op-examples.json"
            |> Path.expand(__DIR__)
            |> File.read!()
            |> Jason.decode!()
            |> Map.fetch!("examples")
            |> Map.new(fn ex -> {ex["op"], ex["request"]} end)

  describe "request builders match the documented op-example shape" do
    test "assemble_request/1" do
      expected = @examples["assemble"]
      assert Ops.assemble_request(expected["events"]) == expected
    end

    test "mine_request/1" do
      expected = @examples["mine"]
      assert Ops.mine_request(expected["receipts"]) == expected
    end

    test "conform_request/2" do
      expected = @examples["conform"]
      assert Ops.conform_request(expected["model"], expected["trace"]) == expected
    end

    test "certify_authzen_evidence_request/6" do
      expected = @examples["certify_authzen_evidence"]

      assert Ops.certify_authzen_evidence_request(
               expected["request"],
               expected["decision"],
               expected["policy_decision_point"],
               expected["expected_policy_decision_point"],
               expected["expected_principal"],
               expected["expected_effect_digest"]
             ) == expected
    end

    test "certify_spiffe_evidence_request/6" do
      expected = @examples["certify_spiffe_evidence"]

      assert Ops.certify_spiffe_evidence_request(
               expected["spiffe_id"],
               expected["expected_spiffe_id"],
               expected["expected_trust_domain"],
               expected["svid_type"],
               expected["bundle_digest"],
               expected["verified"]
             ) == expected
    end

    test "jcs_canonicalize_request/1" do
      expected = @examples["jcs_canonicalize"]
      assert Ops.jcs_canonicalize_request(expected["json"]) == expected
    end

    test "smt_absence_verify_request/6" do
      expected = @examples["smt_absence_verify"]

      assert Ops.smt_absence_verify_request(
               expected["root_hex"],
               expected["queried_key_hex"],
               expected["neighbor_key_hex"],
               expected["neighbor_value_hex"],
               expected["claimed_prefix_bits"],
               expected["proof_steps"]
             ) == expected
    end

    test "range_proof_verify_request/4" do
      expected = @examples["range_proof_verify"]

      assert Ops.range_proof_verify_request(
               expected["commitment_hex"],
               expected["proof_hex"],
               expected["bits"],
               expected["label"]
             ) == expected
    end

    test "example_request/1 resolves every wrapped op" do
      for op <- ~w(assemble mine conform certify_authzen_evidence certify_spiffe_evidence jcs_canonicalize smt_absence_verify range_proof_verify) do
        assert %{"op" => op} = Ops.example_request(op)
      end

      assert Ops.example_request("no_such_op") == nil
    end

    test "all wrapped ops are in the engine's capability registry" do
      ops = AshAffidavit.ops()

      for op <- ~w(assemble mine conform certify_authzen_evidence certify_spiffe_evidence jcs_canonicalize smt_absence_verify range_proof_verify) do
        assert op in ops
      end
    end
  end
end
