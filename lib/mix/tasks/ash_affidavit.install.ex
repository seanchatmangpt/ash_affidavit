# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Igniter
# installer. Recorded in HANDWRITTEN.md.

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAffidavit.Install do
    @shortdoc "Installs ash_affidavit into the current project"
    @moduledoc """
    Installs `ash_affidavit` into the current project: adds the `wasmex` dependency and imports the
    `:ash_affidavit` formatter locals. Run `mix ash_affidavit.vendor` and `mix ash_affidavit.verify`
    afterwards to fetch and check the engine.

        mix igniter.install ash_affidavit
    """
    use Igniter.Mix.Task

    alias Igniter.Project.Deps
    alias Igniter.Project.Formatter

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash_affidavit,
        example: "mix igniter.install ash_affidavit",
        positional: [],
        schema: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Deps.add_dep({:wasmex, "~> 0.15.1"})
      |> Formatter.import_dep(:ash_affidavit)
      |> Igniter.add_notice("""
      AshAffidavit installed.

      Next: mix ash_affidavit.vendor   (fetch the pinned engine wasm)
            mix ash_affidavit.verify   (admit it against the manifest)

      Add `extensions: [AshAffidavit.Resource]` to an Ash.Resource to declare engine operations.
      """)
    end
  end
else
  defmodule Mix.Tasks.AshAffidavit.Install do
    @shortdoc "Installs ash_affidavit (manual steps without Igniter)"
    @moduledoc "Igniter is not a dependency of this project, so this task prints manual steps instead of patching files."
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_affidavit.install' requires igniter to patch files. Install by hand:

        1. add {:wasmex, "~> 0.15.1"} to deps in mix.exs
        2. add import_deps: [:ash_affidavit] to .formatter.exs
        3. run mix ash_affidavit.vendor and mix ash_affidavit.verify

      See https://hexdocs.pm/igniter to install igniter.
      """)

      exit({:shutdown, 1})
    end
  end
end
