# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits a Splode error
# module. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Error.Refused do
  @moduledoc """
  Splode error (class `:invalid`) wrapping an `AshAffidavit.Refusal`.

  Adding it to a changeset makes the Ash action fail while keeping the typed refusal intact. The
  outcome (`:refused`, `:trap` or `:unsupported`) stays distinguishable through `outcome/1`.
  """

  use Splode.Error, fields: [:refusal], class: :invalid

  alias AshAffidavit.Refusal

  @type t :: %__MODULE__{refusal: Refusal.t() | nil}

  @doc "The refusal code, or `nil` when no refusal is attached."
  @spec code(t()) :: atom() | nil
  def code(%__MODULE__{refusal: %Refusal{code: code}}), do: code
  def code(%__MODULE__{}), do: nil

  @doc "The caller-visible outcome (`:refused`, `:trap`, `:unsupported`), or `nil` when no refusal is attached."
  @spec outcome(t()) :: Refusal.outcome() | nil
  def outcome(%__MODULE__{refusal: %Refusal{} = refusal}), do: Refusal.outcome(refusal)
  def outcome(%__MODULE__{}), do: nil

  @impl true
  @spec message(t()) :: String.t()
  def message(%__MODULE__{refusal: %Refusal{code: code, message: message} = refusal}) when is_binary(message),
    do: "AshAffidavit #{Refusal.outcome(refusal)}: #{code}: #{message}"

  def message(%__MODULE__{refusal: %Refusal{code: code}}), do: "AshAffidavit refused: #{code}"
  def message(%__MODULE__{}), do: "AshAffidavit refused: unknown"
end
