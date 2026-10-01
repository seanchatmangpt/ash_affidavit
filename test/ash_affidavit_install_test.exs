# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter.Test) do
  defmodule AshAffidavit.InstallTest do
    # Real Igniter over an in-memory project (Igniter.Test), plus a real `elixir` subprocess for the
    # fallback branch that exists only when Igniter is not loaded.
    use ExUnit.Case, async: true
    import Igniter.Test

    @resource """
    defmodule Demo.Build do
      use Ash.Resource, data_layer: :embedded
    end
    """

    defp project, do: test_project(files: %{"lib/demo/build.ex" => @resource})

    defp source(igniter, path), do: igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

    test "the installer adds the wasmex dep and the formatter import" do
      igniter = test_project() |> Igniter.compose_task("ash_affidavit.install", [])

      assert_has_patch(igniter, "mix.exs", """
      + |      {:wasmex, "~> 0.15.1"}
      """)

      assert_has_patch(igniter, ".formatter.exs", """
      + |  import_deps: [:ash_affidavit]
      """)
    end

    test "the formatter plugin is registered" do
      igniter = test_project() |> Igniter.compose_task("ash_affidavit.install", [])
      assert source(igniter, ".formatter.exs") =~ "AshAffidavit.Formatter"
    end

    test "a bare run only prints the manual notice and leaves resources alone" do
      igniter = project() |> Igniter.compose_task("ash_affidavit.install", [])
      assert Enum.any?(igniter.notices, &(&1 =~ "extensions: [AshAffidavit.Resource]"))
      assert_unchanged(igniter, ["lib/demo/build.ex"])
    end

    test "a second bare run is a no-op" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_affidavit.install", [])
        |> apply_igniter!()
        |> Igniter.compose_task("ash_affidavit.install", [])

      assert_unchanged(igniter, ["mix.exs", ".formatter.exs"])
    end

    test "--target adds the extension and a starter affidavit block" do
      igniter = Igniter.compose_task(project(), "ash_affidavit.install", ["--target", "Demo.Build"])

      content = source(igniter, "lib/demo/build.ex")
      assert content =~ "extensions: [AshAffidavit.Resource]"
      assert content =~ "affidavit do"
    end

    test "a second --target run makes no diff" do
      igniter =
        project()
        |> Igniter.compose_task("ash_affidavit.install", ["--target", "Demo.Build"])
        |> apply_igniter!()
        |> Igniter.compose_task("ash_affidavit.install", ["--target", "Demo.Build"])

      assert_unchanged(igniter)
    end

    test "without Igniter loaded the task is a plain Mix.Task that prints manual steps" do
      file = Path.expand("../lib/mix/tasks/ash_affidavit.install.ex", __DIR__)

      code = """
      Mix.start()
      Code.compile_file(#{inspect(file)})
      false = Code.ensure_loaded?(Igniter)
      true = Mix.Task.task?(Mix.Tasks.AshAffidavit.Install)
      Mix.Tasks.AshAffidavit.Install.run([])
      """

      {out, status} = System.cmd("elixir", ["-e", code], stderr_to_stdout: true, env: [{"MIX_ENV", "prod"}])
      assert status == 0, out
      assert out =~ "Igniter is not installed"
      assert out =~ "extensions: [AshAffidavit.Resource]"
    end
  end
end
