# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter.Test) do
  defmodule AshAffidavit.InstallTest do
    use ExUnit.Case, async: true
    import Igniter.Test

    test "the installer adds the wasmex dep and the formatter import" do
      igniter = test_project() |> Igniter.compose_task("ash_affidavit.install", [])

      assert_has_patch(igniter, "mix.exs", """
      + |      {:wasmex, "~> 0.15.1"}
      """)

      assert_has_patch(igniter, ".formatter.exs", """
      + |  import_deps: [:ash_affidavit]
      """)
    end

    test "a second run is a no-op" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_affidavit.install", [])
        |> apply_igniter!()
        |> Igniter.compose_task("ash_affidavit.install", [])

      assert_unchanged(igniter, ["mix.exs", ".formatter.exs"])
    end
  end
end
