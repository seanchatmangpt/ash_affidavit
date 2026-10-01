# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; the generated Info getters read a persisted
# section key, not the normalized runtime/operations split. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Resource.Declared do
  @moduledoc """
  Reads the normalized `runtime` and `operation` declarations of a resource that uses
  `AshAffidavit.Resource`. The generated `AshAffidavit.Resource.Info` holds the generic accessors
  (`compiled/1`, `compiled!/1`, `compiled?/1`); this module splits the compiled map.

      defmodule MyApp.Build do
        use Ash.Resource,
          domain: MyApp.Domain,
          extensions: [AshAffidavit.Resource]

        affidavit do
          runtime do
            timeout_ms 2_000
          end

          operation :commit
          operation :verify
        end
      end

      AshAffidavit.Resource.Declared.operations(MyApp.Build)

  The section is declarative and checked at compile time (`AshAffidavit.Resource.Validate`).
  Declaring a ceiling grants no authority: this package grants none.
  """

  alias AshAffidavit.Resource.Info

  @doc "The declared `runtime` entity, or `nil`."
  @spec runtime(module()) :: struct() | nil
  def runtime(resource) do
    case compiled(resource) do
      %{runtime: runtime} -> runtime
      _ -> nil
    end
  end

  @doc "The declared `operation` entities (names are strings), in declaration order."
  @spec operations(module()) :: [struct()]
  def operations(resource) do
    case compiled(resource) do
      %{operations: operations} -> operations
      _ -> []
    end
  end

  # A module that is not a Spark DSL module has no declaration (the generated Info assumes one).
  defp compiled(resource) do
    if Code.ensure_loaded?(resource) and function_exported?(resource, :spark_dsl_config, 0),
      do: Info.compiled(resource),
      else: nil
  end
end
