# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; ash-extension-pack passes the raw section
# entities to `aex:normalizeModule` but emits no body for it. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Resource.Normalize do
  @moduledoc """
  Normalizer called by the generated `AshAffidavit.Resource.Persist` transformer
  (`aex:normalizeModule`). It turns the raw `:affidavit` section entities
  (`%{affidavit: [entity]}`) into `%{runtime: struct | nil, operations: [struct]}` with operation
  names as strings, and the generated transformer persists that map as `:ash_affidavit_compiled`.
  """

  alias AshAffidavit.Dsl.Operation
  alias AshAffidavit.Dsl.Runtime

  @doc "Normalizes the raw section map into the compiled declaration."
  @spec normalize(%{affidavit: [struct()]}) :: %{runtime: struct() | nil, operations: [struct()]}
  def normalize(%{affidavit: entities}) do
    %{
      runtime: Enum.find(entities, &match?(%Runtime{}, &1)),
      operations: for(%Operation{} = op <- entities, do: %{op | name: name(op.name)})
    }
  end

  # An op name that is neither atom nor string is kept as its inspected form so the verifier refuses
  # it by name instead of the transformer crashing.
  defp name(name) when is_atom(name) or is_binary(name), do: to_string(name)
  defp name(other), do: inspect(other)
end
