# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a Spark
# transformer. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Resource.Persist do
  @moduledoc """
  Transformer for `AshAffidavit.Resource`: normalizes the raw `:affidavit` entities into one map
  (`%{runtime: struct | nil, operations: [struct]}`, operation names as strings) and persists it
  as `:ash_affidavit_compiled`.
  """
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    entities = Transformer.get_entities(dsl_state, [:affidavit])

    runtime = Enum.find(entities, &match?(%AshAffidavit.Dsl.Runtime{}, &1))

    operations =
      for %AshAffidavit.Dsl.Operation{} = op <- entities do
        %{op | name: to_string(op.name)}
      end

    compiled = %{runtime: runtime, operations: operations}

    {:ok, Transformer.persist(dsl_state, :ash_affidavit_compiled, compiled)}
  end
end
