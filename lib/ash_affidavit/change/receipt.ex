# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack template emits an Ash change.
# Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Change.Receipt do
  @moduledoc """
  Ash change that runs one affidavit engine op against a changeset.

      create :record do
        change {AshAffidavit.Change.Receipt, op: :commit, request: &MyApp.Build.commit_request/1}
      end

  ## Options

    * `:op` - engine op name (atom or string, required). Must be in `AshAffidavit.ops/0`.
    * `:request` - arity-1 function from the changeset to a map of request fields (the `"op"` key
      is set from `:op`). Default: the map in `changeset.context[:affidavit_request]`, else `%{}`.
    * `:phase` - `:before_action` (default) or `:before_transaction`.
    * `:server` - `AshAffidavit.Host` or `AshAffidavit.Pool` pid or name; default routes through
      the shared pool.
    * `:timeout` - per-call timeout in ms (positive integer).
    * `:into` - changeset context key the evidence is stored under (default `:affidavit`).

  ## Outcomes

  On `{:ok, response}` the response map is stored at `changeset.context[into]`. Any other outcome
  (`:refused`, `:trap`, `:unsupported`) adds an `AshAffidavit.Error.Refused` to the changeset, so
  the action fails and the typed `AshAffidavit.Refusal` stays recoverable.

  The response is the engine's computation over the exact request, not an authorization.

  ## Atomic behavior

  `atomic/3` returns `{:not_atomic, reason}`: the engine call cannot be a data-layer expression.
  `Ash.bulk_update/4` with `strategy: :atomic` is refused by Ash; `strategy: :stream` runs the op
  once per record.

  ## Telemetry

  `[:ash_affidavit, :op, :stop]`, measurements `%{duration: native_time}`, metadata
  `%{op: String.t(), outcome: :ok | :refused | :trap | :unsupported, code: atom | nil}`.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias AshAffidavit.Error.Refused

  @allowed_keys [:op, :request, :phase, :server, :timeout, :into]
  @phases [:before_action, :before_transaction]
  @action_types [:create, :update, :destroy]

  @type opts :: [
          op: atom() | String.t(),
          request: (Changeset.t() -> map()) | nil,
          phase: :before_action | :before_transaction,
          server: GenServer.server() | nil,
          timeout: pos_integer() | nil,
          into: atom()
        ]

  @doc "Validates the options at resource compile time."
  @impl true
  @spec init(term()) :: {:ok, opts()} | {:error, String.t()}
  def init(opts) when is_list(opts) do
    with :ok <- check_keys(opts),
         {:ok, op} <- check_op(opts[:op]),
         :ok <- check_phase(Keyword.get(opts, :phase, :before_action)),
         :ok <- check_timeout(opts[:timeout]),
         :ok <- check_request(opts[:request]),
         :ok <- check_into(Keyword.get(opts, :into, :affidavit)) do
      {:ok, Keyword.put(opts, :op, op)}
    end
  end

  def init(_opts), do: {:error, "AshAffidavit.Change.Receipt options must be a keyword list"}

  @doc "Registers the op on create, update and destroy changesets; other action types are untouched."
  @impl true
  @spec change(Changeset.t(), opts(), Ash.Resource.Change.context()) :: Changeset.t()
  def change(%Changeset{action_type: type} = changeset, opts, _context) when type in @action_types do
    case Keyword.get(opts, :phase, :before_action) do
      :before_action -> Changeset.before_action(changeset, &run(&1, opts))
      :before_transaction -> Changeset.before_transaction(changeset, &run(&1, opts))
    end
  end

  def change(changeset, _opts, _context), do: changeset

  @doc "Always `{:not_atomic, reason}`: the op needs a WASM call."
  @impl true
  @spec atomic(Changeset.t(), opts(), Ash.Resource.Change.context()) :: {:not_atomic, String.t()}
  def atomic(_changeset, _opts, _context), do: {:not_atomic, "AshAffidavit receipt op requires a WASM call"}

  @doc """
  Hook body registered by `change/3`: calls the op through `AshAffidavit.call/2` and folds the
  outcome into the changeset. Public only so the hook can be captured.
  """
  @spec run(Changeset.t(), opts()) :: Changeset.t()
  def run(%Changeset{} = changeset, opts) do
    started = System.monotonic_time()
    op = Keyword.fetch!(opts, :op)
    request = Map.put(request_fields(changeset, opts[:request]), "op", op)
    result = AshAffidavit.call(request, call_opts(opts))
    emit(op, result, System.monotonic_time() - started)

    case result do
      {:ok, response} ->
        Changeset.set_context(changeset, %{Keyword.get(opts, :into, :affidavit) => response})

      {_outcome, refusal} ->
        Changeset.add_error(changeset, Refused.exception(refusal: refusal))
    end
  end

  defp request_fields(changeset, nil), do: stringify(Map.get(changeset.context, :affidavit_request, %{}))
  defp request_fields(changeset, fun), do: stringify(fun.(changeset))

  defp stringify(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  defp call_opts(opts) do
    Enum.reject([server: opts[:server], timeout_ms: opts[:timeout]], fn {_k, v} -> is_nil(v) end)
  end

  defp emit(op, result, duration) do
    {outcome, code} =
      case result do
        {:ok, _response} -> {:ok, nil}
        {outcome, refusal} -> {outcome, refusal.code}
      end

    :telemetry.execute([:ash_affidavit, :op, :stop], %{duration: duration}, %{op: op, outcome: outcome, code: code})
  end

  defp check_keys(opts) do
    case Keyword.keys(opts) -- @allowed_keys do
      [] -> :ok
      unknown -> {:error, "unknown options #{inspect(unknown)}; allowed: #{inspect(@allowed_keys)}"}
    end
  end

  defp check_op(op) when is_atom(op) and not is_nil(op), do: check_op(Atom.to_string(op))

  defp check_op(op) when is_binary(op) do
    if op in AshAffidavit.ops(),
      do: {:ok, op},
      else: {:error, "unknown op #{inspect(op)}; the engine offers #{inspect(AshAffidavit.ops())}"}
  end

  defp check_op(_), do: {:error, "`:op` is required and must be an atom or string"}

  defp check_phase(phase) when phase in @phases, do: :ok
  defp check_phase(phase), do: {:error, "`:phase` must be one of #{inspect(@phases)}, got #{inspect(phase)}"}

  defp check_timeout(nil), do: :ok
  defp check_timeout(t) when is_integer(t) and t > 0, do: :ok
  defp check_timeout(t), do: {:error, "`:timeout` must be a positive integer, got #{inspect(t)}"}

  defp check_request(nil), do: :ok
  defp check_request(fun) when is_function(fun, 1), do: :ok
  defp check_request(other), do: {:error, "`:request` must be an arity-1 function, got #{inspect(other)}"}

  defp check_into(into) when is_atom(into), do: :ok
  defp check_into(into), do: {:error, "`:into` must be an atom, got #{inspect(into)}"}
end
