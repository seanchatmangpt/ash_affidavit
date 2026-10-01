# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; the public API over the generated host
# (op registry, three-way outcome mapping) is emitted by no pack. Recorded in HANDWRITTEN.md.

defmodule AshAffidavit do
  @moduledoc """
  Elixir/Ash package around the affidavit WASM engine (Rust, `wasm32-wasip1`, run on the BEAM
  through `wasmex`).

  The engine builds and checks receipts over operation events (`commit`, `assemble`, `verify`),
  mines process models from receipts (`mine`, `conform`) checks a signing input
  (`verify_signature_input`) and certifies external AuthZEN and SPIFFE/SVID evidence
  (`certify_authzen_evidence`, `certify_spiffe_evidence`; authority NONE, evidence only). `ops/0` lists the operations from the engine's own capability
  registry.

  ## Outcomes

  `call/2` returns one of four shapes, kept distinct:

    * `{:ok, response}` - the engine answered `"ok" => true`.
    * `{:refused, %AshAffidavit.Refusal{}}` - the engine refused the input (flat error code such
      as `bad_field`) or the host refused: digest pin, import surface, size bound, saturation.
    * `{:trap, %AshAffidavit.Refusal{}}` - the engine or host failed at run time.
    * `{:unsupported, %AshAffidavit.Refusal{}}` - the operation, or the engine's error code, is
      outside what this library knows.

  ## Authority

  This package grants no execution authority. `{:ok, response}` is the engine's computation over
  exactly the request given, not an authorization, a receipt of any DO, or a standing. Admission
  of the engine bytes (digest pin plus import surface) is an identity check, nothing more.

  ## Running it

      # config/config.exs
      config :ash_affidavit, start_pool: true, pool: [size: 2]

      AshAffidavit.call(%{"op" => "commit", "payload" => "hello"})

  Without `start_pool: true`, start `AshAffidavit.Pool` (or `AshAffidavit.Host`) yourself and
  pass `server: pid_or_name` to `call/2`.
  """

  alias AshAffidavit.ABI
  alias AshAffidavit.Host
  alias AshAffidavit.Pool
  alias AshAffidavit.Refusal

  @registry_path Path.expand("../priv/affidavit/capability-registry.json", __DIR__)
  @external_resource @registry_path
  @registry @registry_path |> File.read!() |> Jason.decode!()

  @type request :: %{optional(String.t() | atom()) => term()}
  @type result ::
          {:ok, map()}
          | {:refused, Refusal.t()}
          | {:trap, Refusal.t()}
          | {:unsupported, Refusal.t()}

  @doc """
  Runs one engine request (a map carrying `"op"`).

  Options: `:server` (a `AshAffidavit.Host` pid or name; default routes through
  `AshAffidavit.Pool`), `:timeout_ms`.
  """
  @spec call(request(), keyword()) :: result()
  def call(request, opts \\ []) when is_map(request) and is_list(opts) do
    {server, host_opts} = Keyword.pop(opts, :server)

    server
    |> route(request, host_opts)
    |> classify()
  end

  @doc "The engine's `capabilities` response (`{:ok, map}` or a typed outcome)."
  @spec capabilities(keyword()) :: result()
  def capabilities(opts \\ []), do: call(%{"op" => "capabilities"}, opts)

  @doc "The ABI version this build speaks (from the contract, equal to the manifest `abi_version`)."
  @spec abi_version() :: pos_integer()
  def abi_version, do: ABI.version()

  @doc "Operation names from the engine's capability registry."
  @spec ops() :: [String.t()]
  def ops, do: Enum.map(@registry["ops"], & &1["name"])

  @doc "The decoded engine capability registry (`priv/affidavit/capability-registry.json`)."
  @spec registry() :: map()
  def registry, do: @registry

  defp route(nil, request, opts), do: Pool.request(request, opts)
  defp route(server, request, opts), do: Host.request(server, request, opts)

  defp classify({:ok, %{"ok" => true} = response}), do: {:ok, response}

  defp classify({:ok, %{"ok" => false, "error" => error}}), do: wrap(Refusal.from_engine(error))

  defp classify({:ok, other}) do
    wrap(Refusal.new(:malformed_response, "engine response has no boolean `ok`", %{response: inspect(other, limit: 5)}))
  end

  defp classify({:error, %Refusal{} = refusal}), do: wrap(refusal)

  defp wrap(%Refusal{} = refusal), do: {Refusal.outcome(refusal), refusal}
end
