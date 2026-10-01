# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Ash notifier.
# Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Notifier do
  @moduledoc """
  Ash notifier that emits a telemetry event after an action that carried engine evidence.

      use Ash.Resource, simple_notifiers: [AshAffidavit.Notifier]

  Event `[:ash_affidavit, :notifier, :action]`, measurements `%{count: 1}`, metadata
  `%{resource: module, action: atom, evidence: map}`. It fires only when
  `AshAffidavit.Change.Receipt` stored evidence under the default `:affidavit` context key of the
  changeset. The event is an observation; it grants no authority.
  """

  use Ash.Notifier

  @impl true
  def notify(%Ash.Notifier.Notification{resource: resource, action: action, changeset: changeset}) do
    case changeset && changeset.context[:affidavit] do
      evidence when is_map(evidence) ->
        :telemetry.execute([:ash_affidavit, :notifier, :action], %{count: 1}, %{
          resource: resource,
          action: action.name,
          evidence: evidence
        })

      _ ->
        :ok
    end

    :ok
  end
end
