# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Ash
# validation. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Validation.Verified do
  @moduledoc """
  Ash validation: the receipt held in `:attribute` must be accepted by the engine's `verify` op.

      validate {AshAffidavit.Validation.Verified, attribute: :receipt}

  A `nil` attribute passes (use `allow_nil?: false` on the attribute to require it). A receipt the
  engine rejects, and any refused, trapped or unsupported call, fails the validation. The engine
  verdict is a format check, not an authorization.
  """

  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl true
  def init(opts) do
    case opts[:attribute] do
      attribute when is_atom(attribute) and not is_nil(attribute) -> {:ok, opts}
      _ -> {:error, "`:attribute` is required and must be an atom"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)

    case Changeset.get_attribute(changeset, attribute) do
      nil ->
        :ok

      receipt ->
        case AshAffidavit.call(%{"op" => "verify", "receipt" => receipt}, server_opts(opts)) do
          {:ok, %{"accepted" => true}} ->
            :ok

          {:ok, response} ->
            {:error, field: attribute, message: "receipt not accepted: #{inspect(response["reason"])}"}

          {outcome, refusal} ->
            {:error, field: attribute, message: "receipt verification #{outcome}: #{refusal.code}"}
        end
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context), do: {:not_atomic, "AshAffidavit verification requires a WASM call"}

  @impl true
  def describe(opts), do: [message: "must be a receipt the engine accepts", vars: [attribute: opts[:attribute]]]

  defp server_opts(opts), do: Enum.reject([server: opts[:server]], fn {_k, v} -> is_nil(v) end)
end
