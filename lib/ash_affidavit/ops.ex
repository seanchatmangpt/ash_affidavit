# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# Lane EA60 (v26.10.5 wave): typed wrappers over the wasm-ABI ops that previously had only the
# generic `AshAffidavit.call/2` path. One typed function per op plus a pure request-map builder,
# mirroring the `AshAffidavit.Signing.verify_signature/4` pattern.
# UNSUPPORTED(generator-capability): no pack template emits typed op wrappers; ledgered in HANDWRITTEN.md.

defmodule AshAffidavit.Ops do
  @moduledoc """
  Typed wrappers over the engine's wasm-ABI operations.

  Every operation in `AshAffidavit.ops/0` is reachable through the generic
  `AshAffidavit.call/2` path; this module adds one typed function and one pure
  request-map builder per op that previously lacked a wrapper
  (`assemble`, `mine`, `conform`, `certify_authzen_evidence`, `certify_spiffe_evidence`,
  `jcs_canonicalize`, `smt_absence_verify`, `range_proof_verify`).

  Each builder returns the exact string-keyed request map the engine expects —
  the same shape documented by `priv/affidavit/op-examples.json` — and the typed
  function forwards it through `AshAffidavit.call/2`:

      {:ok, map()}
      | {:refused, %AshAffidavit.Refusal{}}
      | {:trap, %AshAffidavit.Refusal{}}
      | {:unsupported, %AshAffidavit.Refusal{}}

  Builders are pure and public so courts can assert the built request against the
  registry examples without a live engine. All typed functions accept `:server`
  and `:timeout_ms`, forwarded to `AshAffidavit.call/2`.
  """

  @registry_path Path.expand("../../priv/affidavit/op-examples.json", __DIR__)
  @external_resource @registry_path
  @examples @registry_path |> File.read!() |> Jason.decode!() |> Map.fetch!("examples")

  @doc "The documented example request for `op` from `priv/affidavit/op-examples.json`."
  @spec example_request(String.t()) :: map() | nil
  def example_request(op) when is_binary(op) do
    @examples
    |> Enum.find(&(&1["op"] == op))
    |> case do
      nil -> nil
      example -> example["request"]
    end
  end

  # ---------------------------------------------------------------------
  # assemble
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `assemble` op.

  `events` is a list of string-keyed event maps, each with `"event_type"`,
  `"objects"` and `"payload"`.
  """
  @spec assemble_request([map()]) :: %{required(String.t()) => term()}
  def assemble_request(events) when is_list(events),
    do: %{"op" => "assemble", "events" => events}

  @doc """
  Chains a list of events into a receipt through the engine's `assemble` op.

  `events` is a list of string-keyed event maps (`"event_type"`, `"objects"`,
  `"payload"`). Reads `:server`/`:timeout_ms`.
  """
  @spec assemble([map()], keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def assemble(events, opts \\ []) when is_list(events) and is_list(opts) do
    call(assemble_request(events), opts)
  end

  # ---------------------------------------------------------------------
  # mine
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `mine` op: a list of receipts to mine
  a process model from.
  """
  @spec mine_request([map()]) :: %{required(String.t()) => term()}
  def mine_request(receipts) when is_list(receipts),
    do: %{"op" => "mine", "receipts" => receipts}

  @doc """
  Mines a process model from a list of receipts through the engine's `mine` op.
  Reads `:server`/`:timeout_ms`.
  """
  @spec mine([map()], keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def mine(receipts, opts \\ []) when is_list(receipts) and is_list(opts) do
    call(mine_request(receipts), opts)
  end

  # ---------------------------------------------------------------------
  # conform
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `conform` op: a mined `model` and an
  observed `trace` receipt.
  """
  @spec conform_request([map()], map()) :: %{required(String.t()) => term()}
  def conform_request(model, trace) when is_list(model) and is_map(trace),
    do: %{"op" => "conform", "model" => model, "trace" => trace}

  @doc """
  Checks an observed trace against a mined process model through the engine's
  `conform` op. Reads `:server`/`:timeout_ms`.
  """
  @spec conform([map()], map(), keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def conform(model, trace, opts \\ []) when is_list(model) and is_map(trace) and is_list(opts) do
    call(conform_request(model, trace), opts)
  end

  # ---------------------------------------------------------------------
  # certify_authzen_evidence
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `certify_authzen_evidence` op: the
  AuthZEN `request` document, the `decision`, the policy decision point, and the
  caller-attested expectations the engine binds against.
  """
  @spec certify_authzen_evidence_request(map(), boolean(), String.t() | nil, String.t() | nil, String.t() | nil, String.t() | nil) ::
          %{required(String.t()) => term()}
  def certify_authzen_evidence_request(request, decision, policy_decision_point, expected_policy_decision_point, expected_principal, expected_effect_digest)
      when is_map(request) and is_boolean(decision) do
    %{
      "op" => "certify_authzen_evidence",
      "request" => request,
      "decision" => decision,
      "policy_decision_point" => policy_decision_point,
      "expected_policy_decision_point" => expected_policy_decision_point,
      "expected_principal" => expected_principal,
      "expected_effect_digest" => expected_effect_digest
    }
  end

  @doc """
  Certifies AuthZEN evidence through the engine's `certify_authzen_evidence` op.

  `request` is the AuthZEN access-evaluation document; the remaining arguments
  are the decision, the policy decision point, and the caller-attested
  expectations. Reads `:server`/`:timeout_ms`.
  """
  @spec certify_authzen_evidence(map(), boolean(), String.t() | nil, String.t() | nil, String.t() | nil, String.t() | nil, keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def certify_authzen_evidence(request, decision, policy_decision_point, expected_policy_decision_point, expected_principal, expected_effect_digest, opts \\ [])
      when is_map(request) and is_boolean(decision) and is_list(opts) do
    call(
      certify_authzen_evidence_request(
        request,
        decision,
        policy_decision_point,
        expected_policy_decision_point,
        expected_principal,
        expected_effect_digest
      ),
      opts
    )
  end

  # ---------------------------------------------------------------------
  # certify_spiffe_evidence
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `certify_spiffe_evidence` op: the
  SPIFFE ID, the caller-attested expectations, the SVID type, bundle digest, and
  the caller's own verification verdict.
  """
  @spec certify_spiffe_evidence_request(String.t(), String.t(), String.t(), String.t(), String.t(), boolean()) ::
          %{required(String.t()) => term()}
  def certify_spiffe_evidence_request(spiffe_id, expected_spiffe_id, expected_trust_domain, svid_type, bundle_digest, verified)
      when is_binary(spiffe_id) and is_binary(expected_spiffe_id) and is_binary(expected_trust_domain) and
             is_binary(svid_type) and is_binary(bundle_digest) and is_boolean(verified) do
    %{
      "op" => "certify_spiffe_evidence",
      "spiffe_id" => spiffe_id,
      "expected_spiffe_id" => expected_spiffe_id,
      "expected_trust_domain" => expected_trust_domain,
      "svid_type" => svid_type,
      "bundle_digest" => bundle_digest,
      "verified" => verified
    }
  end

  @doc """
  Certifies SPIFFE/SVID evidence through the engine's `certify_spiffe_evidence` op.
  Reads `:server`/`:timeout_ms`.
  """
  @spec certify_spiffe_evidence(String.t(), String.t(), String.t(), String.t(), String.t(), boolean(), keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def certify_spiffe_evidence(spiffe_id, expected_spiffe_id, expected_trust_domain, svid_type, bundle_digest, verified, opts \\ [])
      when is_binary(spiffe_id) and is_binary(expected_spiffe_id) and is_binary(expected_trust_domain) and
             is_binary(svid_type) and is_binary(bundle_digest) and is_boolean(verified) and is_list(opts) do
    call(
      certify_spiffe_evidence_request(
        spiffe_id,
        expected_spiffe_id,
        expected_trust_domain,
        svid_type,
        bundle_digest,
        verified
      ),
      opts
    )
  end

  # ---------------------------------------------------------------------
  # jcs_canonicalize
  # ---------------------------------------------------------------------

  @doc "Builds the request map for the engine's `jcs_canonicalize` op."
  @spec jcs_canonicalize_request(String.t()) :: %{required(String.t()) => term()}
  def jcs_canonicalize_request(json) when is_binary(json),
    do: %{"op" => "jcs_canonicalize", "json" => json}

  @doc """
  RFC 8785 (JCS) canonicalizes a JSON document string through the engine's
  `jcs_canonicalize` op. Reads `:server`/`:timeout_ms`.
  """
  @spec jcs_canonicalize(String.t(), keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def jcs_canonicalize(json, opts \\ []) when is_binary(json) and is_list(opts) do
    call(jcs_canonicalize_request(json), opts)
  end

  # ---------------------------------------------------------------------
  # smt_absence_verify
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `smt_absence_verify` op: the sparse
  Merkle tree root, the queried key, the absence-neighbor material, the claimed
  prefix depth, and the proof steps.
  """
  @spec smt_absence_verify_request(String.t(), String.t(), String.t(), String.t(), non_neg_integer(), [map()]) ::
          %{required(String.t()) => term()}
  def smt_absence_verify_request(root_hex, queried_key_hex, neighbor_key_hex, neighbor_value_hex, claimed_prefix_bits, proof_steps)
      when is_binary(root_hex) and is_binary(queried_key_hex) and is_binary(neighbor_key_hex) and
             is_binary(neighbor_value_hex) and is_integer(claimed_prefix_bits) and claimed_prefix_bits >= 0 and
             is_list(proof_steps) do
    %{
      "op" => "smt_absence_verify",
      "root_hex" => root_hex,
      "queried_key_hex" => queried_key_hex,
      "neighbor_key_hex" => neighbor_key_hex,
      "neighbor_value_hex" => neighbor_value_hex,
      "claimed_prefix_bits" => claimed_prefix_bits,
      "proof_steps" => proof_steps
    }
  end

  @doc """
  Verifies a sparse Merkle tree absence proof through the engine's
  `smt_absence_verify` op. Reads `:server`/`:timeout_ms`.
  """
  @spec smt_absence_verify(String.t(), String.t(), String.t(), String.t(), non_neg_integer(), [map()], keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def smt_absence_verify(root_hex, queried_key_hex, neighbor_key_hex, neighbor_value_hex, claimed_prefix_bits, proof_steps, opts \\ [])
      when is_binary(root_hex) and is_binary(queried_key_hex) and is_binary(neighbor_key_hex) and
             is_binary(neighbor_value_hex) and is_integer(claimed_prefix_bits) and claimed_prefix_bits >= 0 and
             is_list(proof_steps) and is_list(opts) do
    call(
      smt_absence_verify_request(
        root_hex,
        queried_key_hex,
        neighbor_key_hex,
        neighbor_value_hex,
        claimed_prefix_bits,
        proof_steps
      ),
      opts
    )
  end

  # ---------------------------------------------------------------------
  # range_proof_verify
  # ---------------------------------------------------------------------

  @doc """
  Builds the request map for the engine's `range_proof_verify` op: the Pedersen
  commitment, the zero-knowledge proof, the bit width, and the domain label.
  """
  @spec range_proof_verify_request(String.t(), String.t(), pos_integer(), String.t()) ::
          %{required(String.t()) => term()}
  def range_proof_verify_request(commitment_hex, proof_hex, bits, label)
      when is_binary(commitment_hex) and is_binary(proof_hex) and is_integer(bits) and bits > 0 and is_binary(label) do
    %{
      "op" => "range_proof_verify",
      "commitment_hex" => commitment_hex,
      "proof_hex" => proof_hex,
      "bits" => bits,
      "label" => label
    }
  end

  @doc """
  Verifies a zero-knowledge range proof through the engine's
  `range_proof_verify` op. Reads `:server`/`:timeout_ms`.
  """
  @spec range_proof_verify(String.t(), String.t(), pos_integer(), String.t(), keyword()) ::
          {:ok, map()} | {:refused, AshAffidavit.Refusal.t()}
          | {:trap, AshAffidavit.Refusal.t()} | {:unsupported, AshAffidavit.Refusal.t()}
  def range_proof_verify(commitment_hex, proof_hex, bits, label, opts \\ [])
      when is_binary(commitment_hex) and is_binary(proof_hex) and is_integer(bits) and bits > 0 and
             is_binary(label) and is_list(opts) do
    call(range_proof_verify_request(commitment_hex, proof_hex, bits, label), opts)
  end

  # ---------------------------------------------------------------------
  # Shared plumbing
  # ---------------------------------------------------------------------

  defp call(request, opts), do: AshAffidavit.call(request, Keyword.take(opts, [:server, :timeout_ms]))
end
