# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a Spark info
# module. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Resource.Info do
  @moduledoc """
  Introspection of the `affidavit` section declared with `AshAffidavit.Resource`.
  """

  alias Spark.Dsl.Extension

  @doc "The normalized declaration (`%{runtime: _, operations: [_]}`), or `nil` when the resource does not carry the extension."
  @spec compiled(Ash.Resource.t() | module()) :: map() | nil
  def compiled(resource) do
    if Code.ensure_loaded?(resource) and function_exported?(resource, :spark_dsl_config, 0),
      do: Extension.get_persisted(resource, :ash_affidavit_compiled, nil),
      else: nil
  end

  @doc "Like `compiled/1`; raises `ArgumentError` when the resource carries no compiled declaration."
  @spec compiled!(Ash.Resource.t() | module()) :: map()
  def compiled!(resource) do
    case compiled(resource) do
      nil -> raise ArgumentError, "#{inspect(resource)} does not use AshAffidavit.Resource"
      compiled -> compiled
    end
  end

  @doc "Does `resource` carry a compiled `affidavit` declaration?"
  @spec compiled?(Ash.Resource.t() | module()) :: boolean()
  def compiled?(resource), do: compiled(resource) != nil

  @doc "The declared `runtime` entity, or `nil`."
  @spec runtime(Ash.Resource.t() | module()) :: AshAffidavit.Dsl.Runtime.t() | nil
  def runtime(resource) do
    case compiled(resource) do
      %{runtime: runtime} -> runtime
      _ -> nil
    end
  end

  @doc "The declared `operation` entities (names are strings), in declaration order."
  @spec operations(Ash.Resource.t() | module()) :: [AshAffidavit.Dsl.Operation.t()]
  def operations(resource) do
    case compiled(resource) do
      %{operations: operations} -> operations
      _ -> []
    end
  end
end
