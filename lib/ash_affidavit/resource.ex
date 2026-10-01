defmodule AshAffidavit.Dsl.Runtime do
  @moduledoc false

  defstruct [
    :wasm_path,
    :server,
    :__identifier__,
    :__spark_metadata__,
    timeout_ms: 5000,
    trusted_keys: [],
    singleton: true
  ]
end

defmodule AshAffidavit.Dsl.Operation do
  @moduledoc false

  @enforce_keys [:name]

  defstruct [
    :name,
    :doc,
    :__identifier__,
    :__spark_metadata__,
    ceiling: :observe
  ]
end

defmodule AshAffidavit.Resource do
  @moduledoc """
  Spark.Dsl.Extension for `ash_affidavit`.

  Manufactured by ash-extension-core-pack from an admitted `aex:AshExtensionSpec` --
  do not hand-edit; regenerate from the spec instead.
  """

  @runtime %Spark.Dsl.Entity{
    name: :runtime,
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
        doc: "True routes calls through the shared default pool when no server is given. False requires server."
      ]
    ]
  }

  @operation %Spark.Dsl.Entity{
    name: :operation,
    target: AshAffidavit.Dsl.Operation,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :any,
        required: true,
        doc:
          "Engine op name as an atom or string, for example :commit or :verify. Must be a member of AshAffidavit.ops/0; checked by the verifier."
      ],
      ceiling: [
        type: :atom,
        required: false,
        default: :observe,
        doc:
          "Authority ceiling declared for the op: observe, select or construct. Declaring a ceiling never grants authority."
      ],
      doc: [type: :string, required: false, doc: "Free-text note on why the resource uses the op."]
    ]
  }

  @affidavit %Spark.Dsl.Section{
    name: :affidavit,
    describe: "Affidavit engine configuration: one runtime entity and any number of operations.",
    entities: [
      @runtime,
      @operation
    ],
    singleton_entity_keys: [:runtime]
  }

  use Spark.Dsl.Extension,
    sections: [@affidavit],
    transformers: [AshAffidavit.Resource.Persist],
    verifiers: [AshAffidavit.Resource.Verify],
    single_extension_kinds: [:ash_affidavit]
end
