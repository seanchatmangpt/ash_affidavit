# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a Spark
# formatter plugin helper. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Formatter do
  @moduledoc """
  `Spark.Formatter` helper for the `affidavit` section. It lists the extensions this package
  exports. Without a plugin of its own, a consumer enables the formatting with `Spark.Formatter`
  and `import_deps: [:ash_affidavit]` in `.formatter.exs`.
  """

  @doc "The Spark extensions exported by AshAffidavit."
  @spec extensions() :: [module()]
  def extensions, do: [AshAffidavit.Resource]

  @doc "Mix.Tasks.Format plugin callback."
  @spec features(keyword()) :: keyword()
  def features(_opts), do: [extensions: [".ex", ".exs"]]

  @doc "Mix.Tasks.Format plugin callback; returns the contents unchanged when `Spark.Formatter` is unavailable."
  @spec format(String.t(), keyword()) :: String.t()
  def format(contents, opts) do
    if Code.ensure_loaded?(Spark.Formatter) do
      opts =
        Keyword.update(opts, :spark, [extensions: extensions()], fn spark ->
          Keyword.update(spark, :extensions, extensions(), &Enum.uniq(extensions() ++ &1))
        end)

      Spark.Formatter.format(contents, opts)
    else
      contents
    end
  end
end
