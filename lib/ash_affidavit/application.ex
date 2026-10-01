# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack emits an OTP application callback.
# Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Application do
  @moduledoc """
  OTP application callback.

  Starts `AshAffidavit.Pool` only when `config :ash_affidavit, start_pool: true` (default
  `false`), so depending on the library never loads or instantiates the WASM engine implicitly.
  `config :ash_affidavit, pool: [size: 4, timeout_ms: 5_000]` is handed to the pool.

  Nothing here grants execution authority.
  """

  use Application

  @doc "Children started under `AshAffidavit.Supervisor` for the current config."
  @spec children() :: [Supervisor.child_spec() | module() | {module(), term()}]
  def children do
    if Application.get_env(:ash_affidavit, :start_pool, false) do
      [{AshAffidavit.Pool, pool_opts()}]
    else
      []
    end
  end

  @impl Application
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one, name: AshAffidavit.Supervisor)
  end

  defp pool_opts do
    case Application.get_env(:ash_affidavit, :pool, []) do
      opts when is_list(opts) -> opts
      _ -> []
    end
  end
end
