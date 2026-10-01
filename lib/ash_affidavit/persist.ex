defmodule AshAffidavit.Resource.Persist do
  @moduledoc """
  Transformer for `ash_affidavit`: normalizes the raw `:affidavit`
  DSL entities into a compiled struct and persists it as `:ash_affidavit_compiled`.
  """
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    affidavit_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:affidavit])

    compiled = %{
      affidavit: affidavit_entities
    }

    compiled = AshAffidavit.Resource.Normalize.normalize(compiled)

    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :ash_affidavit_compiled, compiled)}
  end
end
