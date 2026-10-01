# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Ash
# calculation. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Calculation.Verdict do
  @moduledoc """
  Ash calculation: the engine's `verify` verdict for the receipt held in `:attribute`.

      calculate :verdict, :atom, {AshAffidavit.Calculation.Verdict, attribute: :receipt}

  Each record yields `:accept` or `:reject` (the engine's own `accepted`), `:refused`, `:trap` or
  `:unsupported` for the other `AshAffidavit.call/2` outcomes, and `nil` when the attribute is
  `nil`. A verdict is a format check, not an authorization.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    case opts[:attribute] do
      attribute when is_atom(attribute) and not is_nil(attribute) -> {:ok, opts}
      _ -> {:error, "`:attribute` is required and must be an atom"}
    end
  end

  @impl true
  def load(_query, opts, _context), do: [Keyword.fetch!(opts, :attribute)]

  @impl true
  def calculate(records, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)
    call_opts = Enum.reject([server: opts[:server]], fn {_k, v} -> is_nil(v) end)

    Enum.map(records, fn record ->
      case Map.get(record, attribute) do
        nil -> nil
        receipt -> verdict(AshAffidavit.call(%{"op" => "verify", "receipt" => receipt}, call_opts))
      end
    end)
  end

  defp verdict({:ok, %{"accepted" => true}}), do: :accept
  defp verdict({:ok, _response}), do: :reject
  defp verdict({outcome, _refusal}), do: outcome
end
