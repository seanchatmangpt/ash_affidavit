if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAffidavit.Install do
    @moduledoc """
    Installs `ash_affidavit` into the current project: adds the formatter plugin,
    and patches the target resource module to add
    `extensions: [AshAffidavit.Resource]` plus a starter `:affidavit` block.
    """
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash_affidavit,
        example: "mix ash_affidavit.install --target MyApp.SomeResource",
        positional: [],
        schema: [target: :string],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      base =
        igniter
        |> Igniter.Project.Deps.add_dep({:wasmex, "~> 0.15.1"})
        |> Igniter.Project.Formatter.import_dep(:ash_affidavit)
        |> Igniter.Project.Formatter.add_formatter_plugin(AshAffidavit.Formatter)

      case igniter.args.options[:target] do
        nil ->
          # No --target given (e.g. plain `mix igniter.install ash_affidavit`) --
          # formatter is still wired up automatically; the resource/domain patch needs a
          # target module, so fall back to a real, disclosed manual-instructions notice
          # rather than guessing which module to patch.
          Igniter.add_notice(base, """
          AshAffidavit.Resource installed successfully!

          Add `extensions: [AshAffidavit.Resource]` to your Ash.Resource modules:

              use Ash.Resource,
                extensions: [AshAffidavit.Resource]

              affidavit do
              end

          Or re-run with `--target MyApp.SomeResource` to patch a specific module automatically.
          """)

        target ->
          target_module = Igniter.Project.Module.parse(target)

          base
          |> Spark.Igniter.add_extension(target_module, Ash.Resource, :extensions, AshAffidavit.Resource)
          |> Igniter.Project.Module.find_and_update_module!(target_module, &add_starter_dsl_block/1)
      end
    end

    # Adds a minimal, real starter block for the primary section so the target module
    # compiles immediately after install rather than needing hand-authored DSL content.
    # Skipped when the block already exists, so a second run is a no-op. The extension
    # itself is added by `Spark.Igniter.add_extension/5` above, which emits valid Elixir,
    # is idempotent, and merges into an existing `extensions:` list instead of inserting a
    # second option (a bare `extensions: [...]` fragment is not a statement and cannot be
    # inserted with `Igniter.Code.Common.add_code/3`).
    defp add_starter_dsl_block(zipper) do
      already? =
        zipper
        |> Sourceror.Zipper.node()
        |> Sourceror.to_string()
        |> String.contains?("affidavit do")

      if already? do
        {:ok, zipper}
      else
        {:ok,
         Igniter.Code.Common.add_code(
           zipper,
           """
           affidavit do
           end
           """,
           placement: :after
         )}
      end
    end
  end
else
  defmodule Mix.Tasks.AshAffidavit.Install do
    @moduledoc "Installs `ash_affidavit` -- Igniter is not a dependency of this project, so this task prints manual instructions instead of patching files."
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().info("""
      AshAffidavit.Resource: Igniter is not installed, so `ash_affidavit.install` cannot
      patch files automatically. Add `extensions: [AshAffidavit.Resource]` to your
      Ash.Resource modules by hand:

          use Ash.Resource,
            extensions: [AshAffidavit.Resource]

          affidavit do
          end
      """)
    end
  end
end
