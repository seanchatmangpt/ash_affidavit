# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a Spark
# verifier. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Resource.Verify do
  @moduledoc """
  Verifier for `AshAffidavit.Resource`. Raises `Spark.Error.DslError` at compile time for

    * an `operation` whose name is not in `AshAffidavit.ops/0` (the engine's capability registry),
    * a `ceiling` outside `:observe`, `:select`, `:construct`,
    * a `timeout_ms` that is not a positive integer,
    * a `trusted_keys` entry that is not 64 hex characters,
    * `singleton false` without a `server`.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @ceilings [:observe, :select, :construct]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    case Verifier.get_persisted(dsl_state, :ash_affidavit_compiled) do
      nil ->
        {:error,
         DslError.exception(
           module: module,
           path: [:affidavit],
           message: "ash_affidavit: transformer did not persist :ash_affidavit_compiled"
         )}

      %{runtime: runtime, operations: operations} ->
        with :ok <- check_runtime(module, runtime) do
          check_operations(module, operations)
        end
    end
  end

  defp check_operations(module, operations) do
    known = AshAffidavit.ops()

    Enum.find_value(operations, :ok, fn op ->
      cond do
        op.name not in known ->
          error(
            module,
            [:affidavit, :operation, op.name],
            "unknown operation #{inspect(op.name)}; the engine offers #{inspect(known)}"
          )

        op.ceiling not in @ceilings ->
          error(
            module,
            [:affidavit, :operation, op.name, :ceiling],
            "ceiling must be one of #{inspect(@ceilings)}, got #{inspect(op.ceiling)}"
          )

        true ->
          nil
      end
    end)
  end

  defp check_runtime(_module, nil), do: :ok

  defp check_runtime(module, runtime) do
    path = [:affidavit, :runtime]

    cond do
      not (is_integer(runtime.timeout_ms) and runtime.timeout_ms > 0) ->
        error(
          module,
          path ++ [:timeout_ms],
          "timeout_ms must be a positive integer, got #{inspect(runtime.timeout_ms)}"
        )

      bad = Enum.find(runtime.trusted_keys, &(not hex_key?(&1))) ->
        error(module, path ++ [:trusted_keys], "trusted_keys entries must be 64 hex characters, got #{inspect(bad)}")

      runtime.singleton == false and is_nil(runtime.server) ->
        error(module, path ++ [:server], "singleton false requires a server")

      true ->
        :ok
    end
  end

  defp hex_key?(key), do: is_binary(key) and String.match?(key, ~r/\A[0-9a-fA-F]{64}\z/)

  defp error(module, path, message) do
    {:error, DslError.exception(module: module, path: path, message: message)}
  end
end
