# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.AuthorityNoneTest do
  # Authority ceiling NONE over every op of the real engine: no response may grant authority, and no
  # response may state a standing of ALIVE. Positive control: at least one response states authority.
  use ExUnit.Case, async: false

  @examples Path.expand("../priv/affidavit/op-examples.json", __DIR__) |> File.read!() |> Jason.decode!()

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 2})
    :ok
  end

  defp walk(term, acc \\ [])
  defp walk(map, acc) when is_map(map), do: Enum.reduce(map, acc, fn {k, v}, a -> walk(v, [{k, v} | a]) end)
  defp walk(list, acc) when is_list(list), do: Enum.reduce(list, acc, &walk/2)
  defp walk(_, acc), do: acc

  test "the examples cover all 9 ops" do
    assert length(@examples["examples"]) == 9
    assert Enum.sort(Enum.map(@examples["examples"], & &1["op"])) == Enum.sort(AshAffidavit.ops())
  end

  test "every op's response states authority NONE or none, and never standing ALIVE" do
    pairs =
      for ex <- @examples["examples"] do
        {:ok, response} = AshAffidavit.call(ex["request"])
        {ex["op"], walk(response)}
      end

    stated = for {op, kvs} <- pairs, {"authority", v} <- kvs, do: {op, v}
    assert stated != [], "positive control: no op states authority"
    for {op, v} <- stated, do: assert(v in ["NONE", "none", nil], "#{op} states authority #{inspect(v)}")

    for {op, kvs} <- pairs, {"standing", v} <- kvs, do: refute(v == "ALIVE", "#{op} states standing ALIVE")
  end
end
