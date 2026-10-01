# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; ash-extension-pack's reactor_step template emits an
# arguments-echo stub, not a step that calls the engine. Recorded in HANDWRITTEN.md.

# Reactor is an optional dependency: the module exists only when `Reactor.Step` is loadable.
if Code.ensure_loaded?(Reactor.Step) do
  defmodule AshAffidavit.Reactor.Step do
    @moduledoc """
    Reactor step that runs one affidavit engine op through `AshAffidavit.call/2`.

        defmodule MyApp.Flow do
          use Reactor

          input :payload

          step :commit, {AshAffidavit.Reactor.Step, op: :commit} do
            argument :payload, input(:payload)
          end

          return :commit
        end

    The step's resolved arguments are the engine request fields (the `"op"` key is set from the
    `:op` option). Options: `:op` (required), `:server` (a `AshAffidavit.Host` or `AshAffidavit.Pool`
    pid or name; default routes through the shared pool), `:timeout_ms`.

    `{:ok, response}` is the step result. `:refused`, `:trap` and `:unsupported` outcomes are
    `{:error, %AshAffidavit.Refusal{}}`, so the reactor fails and never continues on them. A `:trap`
    (the host failed at run time) is retried through `compensate/4`; a refusal or unsupported op is
    not. The response is the engine's computation over the exact request, not an authorization.
    """

    use Reactor.Step

    alias AshAffidavit.Refusal

    @impl true
    def run(arguments, _context, options) do
      case Keyword.fetch(options, :op) do
        {:ok, op} when is_atom(op) or is_binary(op) ->
          request = arguments |> Map.new(fn {k, v} -> {to_string(k), v} end) |> Map.put("op", to_string(op))

          case AshAffidavit.call(request, call_opts(options)) do
            {:ok, response} -> {:ok, response}
            {_outcome, %Refusal{} = refusal} -> {:error, refusal}
          end

        _ ->
          {:error, Refusal.new(:missing_field, "AshAffidavit.Reactor.Step requires the :op option")}
      end
    end

    @impl true
    def compensate(%Refusal{class: :trap}, _arguments, _context, _options), do: :retry
    def compensate(_reason, _arguments, _context, _options), do: :ok

    defp call_opts(options), do: Keyword.take(options, [:server, :timeout_ms])
  end
end
