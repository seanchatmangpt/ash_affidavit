# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Ash type.
# Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Type.Receipt do
  @moduledoc """
  Ash type for an affidavit receipt: a map with `"chain_hash"` and `"events"` keys (string keys,
  as the engine's `assemble` op returns it). The shape is checked here; whether the chain is
  valid is the engine's `verify` op, see `AshAffidavit.Validation.Verified`.
  """
  use Ash.Type.NewType, subtype_of: :map

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(%{"chain_hash" => hash, "events" => events} = receipt, _constraints)
      when is_binary(hash) and is_list(events),
      do: {:ok, receipt}

  def cast_input(_value, _constraints), do: {:error, "is not a receipt (needs string keys chain_hash and events)"}
end
