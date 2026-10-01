# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; ash-extension-pack emits the verifier shell
# (`aex:validateDelegateModule`) but not the legality checks. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Resource.Validate do
  @moduledoc """
  Legality checks the generated `AshAffidavit.Resource.Verify` delegates to
  (`aex:validateDelegateModule`). The generated verifier raises a `Spark.Error.DslError` at compile
  time for

    * an `operation` whose name is not in `AshAffidavit.ops/0` (the engine's capability registry),
    * a `ceiling` outside `:observe`, `:select`, `:construct`,
    * a `timeout_ms` that is not a positive integer,
    * a `trusted_keys` entry that is not 64 hex characters,
    * `singleton false` without a `server`.

  Every refusal carries `code` and `detail`; the detail names the DSL path. Declaring a ceiling grants
  no authority.
  """

  @ceilings [:observe, :select, :construct]

  @type refusal :: %{code: atom(), detail: String.t()}

  @doc "Checks the compiled declaration; `:ok` or `{:error, [refusal]}` listing every violation."
  @spec validate(%{runtime: struct() | nil, operations: [struct()]}) :: :ok | {:error, [refusal()]}
  def validate(%{runtime: runtime, operations: operations}) do
    case runtime_refusals(runtime) ++ operation_refusals(operations) do
      [] -> :ok
      refusals -> {:error, refusals}
    end
  end

  defp operation_refusals(operations) do
    known = AshAffidavit.ops()

    Enum.flat_map(operations, fn op ->
      unknown =
        if op.name in known,
          do: [],
          else: [
            refusal(
              :unknown_operation,
              [:affidavit, :operation, op.name],
              "unknown operation #{inspect(op.name)}; the engine offers #{inspect(known)}"
            )
          ]

      bad_ceiling =
        if op.ceiling in @ceilings,
          do: [],
          else: [
            refusal(
              :bad_ceiling,
              [:affidavit, :operation, op.name, :ceiling],
              "ceiling must be one of #{inspect(@ceilings)}, got #{inspect(op.ceiling)}"
            )
          ]

      unknown ++ bad_ceiling
    end)
  end

  defp runtime_refusals(nil), do: []

  defp runtime_refusals(runtime) do
    path = [:affidavit, :runtime]

    timeout =
      if is_integer(runtime.timeout_ms) and runtime.timeout_ms > 0,
        do: [],
        else: [
          refusal(
            :bad_timeout,
            path ++ [:timeout_ms],
            "timeout_ms must be a positive integer, got #{inspect(runtime.timeout_ms)}"
          )
        ]

    keys =
      for key <- runtime.trusted_keys, not hex_key?(key) do
        refusal(
          :bad_trusted_key,
          path ++ [:trusted_keys],
          "trusted_keys entries must be 64 hex characters, got #{inspect(key)}"
        )
      end

    singleton =
      if runtime.singleton == false and is_nil(runtime.server),
        do: [refusal(:singleton_without_server, path ++ [:server], "singleton false requires a server")],
        else: []

    timeout ++ keys ++ singleton
  end

  defp hex_key?(key), do: is_binary(key) and String.match?(key, ~r/\A[0-9a-fA-F]{64}\z/)

  defp refusal(code, path, detail), do: %{code: code, detail: "#{inspect(path)} #{detail}"}
end
