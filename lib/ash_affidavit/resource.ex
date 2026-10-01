# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a Spark DSL
# extension. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Dsl.Runtime do
  @moduledoc """
  Struct of the `runtime` entity of the `affidavit` section; see `AshAffidavit.Resource`.
  """

  defstruct [
    :wasm_path,
    :server,
    :__identifier__,
    :__spark_metadata__,
    timeout_ms: 5000,
    trusted_keys: [],
    singleton: true
  ]

  @type t :: %__MODULE__{}
end

defmodule AshAffidavit.Dsl.Operation do
  @moduledoc """
  Struct of an `operation` entity of the `affidavit` section; see `AshAffidavit.Resource`.
  """

  @enforce_keys [:name]

  defstruct [
    :name,
    :doc,
    :__identifier__,
    :__spark_metadata__,
    ceiling: :observe
  ]

  @type t :: %__MODULE__{}
end

defmodule AshAffidavit.Resource do
  @moduledoc """
  `Spark.Dsl.Extension` that declares, on an Ash resource, which affidavit engine operations the
  resource uses and how it reaches the engine.

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

  The section is declarative. It is checked at compile time (`AshAffidavit.Resource.Verify`):
  every `operation` must name an op of the engine's capability registry (`AshAffidavit.ops/0`),
  every `ceiling` must be one of `:observe`, `:select`, `:construct`, and `timeout_ms` must be
  positive. Declaring a ceiling grants no authority: this package grants none. Read the compiled
  declaration back with `AshAffidavit.Resource.Info`.

  Engine calls go through `AshAffidavit.call/2`, for example from
  `AshAffidavit.Change.Receipt`.
  """

  @runtime %Spark.Dsl.Entity{
    name: :runtime,
    describe: "How resource actions reach the affidavit engine.",
    target: AshAffidavit.Dsl.Runtime,
    schema: [
      wasm_path: [
        type: :string,
        required: false,
        doc:
          "Path of the engine wasm this resource expects. Declarative only: the host resolves and digest-pins the engine itself (see AshAffidavit.WasmConfig)."
      ],
      timeout_ms: [
        type: :integer,
        required: false,
        default: 5000,
        doc: "Per-call timeout in milliseconds. Must be positive."
      ],
      trusted_keys: [
        type: {:list, :string},
        required: false,
        default: [],
        doc:
          "Hex-encoded 32-byte public keys (64 characters each) the resource declares as trusted signers. Declarative only."
      ],
      server: [
        type: :any,
        required: false,
        doc:
          "Name or pid of an AshAffidavit.Host or AshAffidavit.Pool to route calls through. Nil routes through the default pool."
      ],
      singleton: [
        type: :boolean,
        required: false,
        default: true,
        doc: "True routes calls through the shared default pool when no server is given. False requires `server`."
      ]
    ]
  }

  @operation %Spark.Dsl.Entity{
    name: :operation,
    describe: "An engine operation this resource uses.",
    target: AshAffidavit.Dsl.Operation,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: {:or, [:atom, :string]},
        required: true,
        doc: "Engine op name, for example :commit or :verify. Must be a member of AshAffidavit.ops/0."
      ],
      ceiling: [
        type: :atom,
        required: false,
        default: :observe,
        doc:
          "Authority ceiling declared for the op: :observe, :select or :construct. Declaring a ceiling never grants authority."
      ],
      doc: [type: :string, required: false, doc: "Free-text note on why the resource uses the op."]
    ]
  }

  @affidavit %Spark.Dsl.Section{
    name: :affidavit,
    describe: "Affidavit engine configuration: one runtime entity and any number of operations.",
    entities: [@runtime, @operation],
    singleton_entity_keys: [:runtime]
  }

  use Spark.Dsl.Extension,
    sections: [@affidavit],
    transformers: [AshAffidavit.Resource.Persist],
    verifiers: [AshAffidavit.Resource.Verify],
    single_extension_kinds: [:ash_affidavit]
end
