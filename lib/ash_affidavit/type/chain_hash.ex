# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Ash type.
# Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Type.ChainHash do
  @moduledoc """
  Ash type for a receipt chain hash or content address: 64 lowercase hex characters (BLAKE3
  digest). Uppercase input is normalized to lowercase.
  """
  use Ash.Type.NewType, subtype_of: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    lower = String.downcase(value)

    if String.match?(lower, ~r/\A[0-9a-f]{64}\z/),
      do: {:ok, lower},
      else: {:error, "is not a 64-character hex digest"}
  end

  def cast_input(_value, _constraints), do: {:error, "is not a 64-character hex digest"}
end
