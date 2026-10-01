# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written test fixture; no pack template emits Ash fixtures.

defmodule AshAffidavit.Test.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshAffidavit.Test.Build
  end
end

defmodule AshAffidavit.Test.Build do
  @moduledoc false
  use Ash.Resource,
    domain: AshAffidavit.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    simple_notifiers: [AshAffidavit.Notifier],
    extensions: [AshAffidavit.Resource]

  alias Ash.Changeset

  ets do
    private? true
  end

  affidavit do
    runtime do
      timeout_ms 5_000
    end

    operation :commit
    operation :verify
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :receipt, AshAffidavit.Type.Receipt, public?: true
    attribute :chain_hash, AshAffidavit.Type.ChainHash, public?: true
  end

  calculations do
    calculate :verdict, :atom, {AshAffidavit.Calculation.Verdict, attribute: :receipt}
  end

  actions do
    defaults [:read, :destroy]

    create :record do
      accept [:name]
      change {AshAffidavit.Change.Receipt, op: :commit, request: &__MODULE__.commit_request/1}
      change &__MODULE__.expose_evidence/2
    end

    # Sends a commit request with no payload: the engine refuses it with `missing_field`.
    create :record_bad do
      accept [:name]
      change {AshAffidavit.Change.Receipt, op: :commit, request: &__MODULE__.empty_request/1}
    end

    create :keep do
      accept [:name, :receipt, :chain_hash]
      validate {AshAffidavit.Validation.Verified, attribute: :receipt}
    end

    update :touch do
      accept [:name]
      require_atomic? false
      change {AshAffidavit.Change.Receipt, op: :commit, request: &__MODULE__.commit_request/1}
      change &__MODULE__.expose_evidence/2
    end
  end

  @doc false
  def empty_request(_changeset), do: %{}

  @doc false
  def commit_request(changeset), do: %{"payload" => Changeset.get_attribute(changeset, :name)}

  # Copies the evidence the change stored in the changeset context onto the record metadata so a
  # test can read it from the action result.
  @doc false
  def expose_evidence(changeset, _context) do
    Changeset.after_action(changeset, fn changeset, record ->
      {:ok, Ash.Resource.put_metadata(record, :affidavit, changeset.context[:affidavit])}
    end)
  end
end
