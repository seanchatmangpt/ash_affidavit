# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

# DSL entity and option calls of the `affidavit` section format without parentheses, here and (through
# `export`) in every project that sets `import_deps: [:ash_affidavit]`.
spark_locals_without_parens = [
  ceiling: 1,
  doc: 1,
  operation: 1,
  operation: 2,
  runtime: 0,
  runtime: 1,
  server: 1,
  singleton: 1,
  timeout_ms: 1,
  trusted_keys: 1,
  wasm_path: 1
]

[
  import_deps: [:ash, :spark],
  plugins: [Spark.Formatter],
  spark: [
    extensions: [AshAffidavit.Resource]
  ],
  line_length: 120,
  trailing_comma: true,
  local_pipe_with_parens: true,
  single_clause_on_do: true,
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
