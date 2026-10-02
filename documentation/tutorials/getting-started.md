<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# Getting started

## Install

```sh
mix igniter.install ash_affidavit
```

Without Igniter, add `{:ash_affidavit, "~> 26.10.1"}` and `{:wasmex, "~> 0.15.1"}` to `deps` and
`import_deps: [:ash_affidavit]` to `.formatter.exs`. Then:

```sh
mix ash_affidavit.vendor --check
mix ash_affidavit.verify
```

## Declare operations on a resource

```elixir
defmodule MyApp.Build do
  use Ash.Resource, domain: MyApp.Domain, extensions: [AshAffidavit.Resource]

  affidavit do
    runtime do
      timeout_ms 2_000
    end

    operation :commit
  end

  actions do
    create :record do
      accept [:name]
      change {AshAffidavit.Change.Receipt, op: :commit, request: &__MODULE__.commit_request/1}
    end
  end

  def commit_request(changeset), do: %{"payload" => Ash.Changeset.get_attribute(changeset, :name)}
end
```

Start the pool with `config :ash_affidavit, start_pool: true`. The engine response is stored at
`changeset.context[:affidavit]`; a refusal fails the action with an `AshAffidavit.Error.Refused`.

AshAffidavit grants no authority: a response is an observation about the exact request.
