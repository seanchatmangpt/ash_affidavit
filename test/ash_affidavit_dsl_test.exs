# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.DslTest do
  # Each case compiles a real embedded resource from source and runs the real verifier over it.
  use ExUnit.Case, async: true

  alias AshAffidavit.Resource.Declared
  alias AshAffidavit.Resource.Verify
  alias ExUnit.CaptureIO

  defp compile(body) do
    name = "AshAffidavit.Test.Dsl#{System.unique_integer([:positive])}"

    _ =
      Code.compile_string("""
      defmodule #{name} do
        use Ash.Resource, data_layer: :embedded, extensions: [AshAffidavit.Resource]

        attributes do
          uuid_primary_key :id
        end

        affidavit do
          #{body}
        end
      end
      """)

    Module.concat([name])
  end

  # Spark runs verifiers in the module's after_verify hook and reports an {:error, DslError} as a
  # compile warning (fatal under `mix compile --warnings-as-errors`). The test compiles the real
  # resource, then runs the real verifier over the compiled DSL state to assert the error value.
  defp verifier_errors(body) do
    {module, _warnings} = with_io_stderr(fn -> compile(body) end)

    case Verify.verify(module.spark_dsl_config()) do
      :ok -> []
      {:error, error} -> [error]
    end
  end

  defp with_io_stderr(fun) do
    parent = self()
    out = CaptureIO.capture_io(:stderr, fn -> send(parent, {:result, fun.()}) end)

    receive do
      {:result, result} -> {result, out}
    end
  end

  defp refuses(body, fragment) do
    assert [%Spark.Error.DslError{} = error] = verifier_errors(body)
    assert Exception.message(error) =~ fragment
  end

  test "a valid declaration compiles with no verifier error" do
    assert verifier_errors("operation :commit\noperation \"verify\", ceiling: :select") == []

    module = AshAffidavit.Test.Build

    assert Enum.map(Declared.operations(module), &{&1.name, &1.ceiling}) ==
             [{"commit", :observe}, {"verify", :observe}]
  end

  test "an unknown op is refused" do
    refuses("operation :teleport", "unknown operation \"teleport\"")
  end

  test "a bad ceiling is refused" do
    refuses("operation :commit, ceiling: :root", "ceiling must be one of")
  end

  test "a non-positive timeout is refused" do
    refuses("runtime do\n timeout_ms 0\n end", "timeout_ms must be a positive integer")
    refuses("runtime do\n timeout_ms(-5)\n end", "timeout_ms must be a positive integer")
  end

  test "a malformed trusted key is refused" do
    refuses("runtime do\n trusted_keys [\"abc\"]\n end", "64 hex characters")
  end

  test "singleton false without a server is refused" do
    refuses("runtime do\n singleton false\n end", "singleton false requires a server")
  end
end
