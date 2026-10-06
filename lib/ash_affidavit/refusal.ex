# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
# UNSUPPORTED(generator-capability): hand-written residue; no pack emits a per-contract refusal
# module. The generated host files alias this module (qri:refusalModule). Recorded in HANDWRITTEN.md.

defmodule AshAffidavit.Refusal do
  @moduledoc """
  Typed refusal carried by every `{:refused | :trap | :unsupported, _}` this library returns.

  The code set is closed. It is the union of

    * host codes: raised by the generated host files (`AshAffidavit.Host`, `EngineLoad`, `ABI`,
      `WasmConfig`, `Pool`) before or around an engine call, and
    * engine codes: the flat `error.code` strings of the affidavit engine's error envelope
      `{"ok": false, "error": {"code": ..., "message": ...}}`, read at compile time from
      `priv/affidavit/capability-registry.json` (`error_codes`).

  `class/1` places each code in one class and `outcome/1` collapses a class into the three
  distinct caller-visible outcomes:

    * `:refused`     - the input, the engine identity or a resource bound was refused; retry
      only with a different input or different bytes.
    * `:refused` also covers class `:refused_authority`: a response that states an authority above
      NONE is never success (`:authority_escalation`).
    * `:trap`        - the engine or the host failed at run time (trap, exit, ABI failure,
      malformed response); the host recycles the instance.
    * `:unsupported` - the engine does not support what was asked (`unknown_op`) or returned
      a code this library does not know (`:engine_unclassified`, carried verbatim in `:raw`).

  A refusal is an observation about one exact input. It grants and withdraws no authority.
  """

  @registry_path Path.expand("../../priv/affidavit/capability-registry.json", __DIR__)
  @external_resource @registry_path
  @engine_codes @registry_path
                |> File.read!()
                |> Jason.decode!()
                |> Map.fetch!("error_codes")

  @engine_input ~w(bad_json missing_field bad_field malformed)
  @engine_resource ~w(too_large too_deep missing_buffer)
  @engine_trap ~w(internal)
  @engine_unsupported ~w(unknown_op)

  # Every engine code must be placed in exactly one class; compilation fails if the registry
  # grows a code this file does not classify.
  @placed @engine_input ++ @engine_resource ++ @engine_trap ++ @engine_unsupported
  if Enum.sort(@placed) != Enum.sort(@engine_codes) do
    raise "AshAffidavit.Refusal: engine error codes #{inspect(@engine_codes -- @placed)} are unclassified " <>
            "(or classified but absent from the registry: #{inspect(@placed -- @engine_codes)})"
  end

  @host_classes %{
    # input could not be encoded or the engine answered with a non-object
    invalid_json: :refused_input,
    invalid_encoding: :refused_input,
    # engine identity / admission
    wasm_digest_mismatch: :refused_identity,
    wasm_import_surface_mismatch: :refused_identity,
    wasm_missing_export: :refused_identity,
    wasm_invalid: :refused_identity,
    # a response that states an authority above NONE is never success (authority ceiling NONE)
    authority_escalation: :refused_authority,
    wasm_not_vendored: :blocked_resource,
    wasm_unreadable: :blocked_resource,
    # resources
    resource_limit: :blocked_resource,
    saturated: :blocked_resource,
    host_not_started: :blocked_resource,
    call_timeout: :blocked_resource,
    fuel_exhausted: :blocked_resource,
    # run-time failures
    call_trapped: :trap,
    call_exited: :trap,
    abi_failure: :trap,
    instantiation_failed: :trap,
    malformed_response: :trap,
    # engine said something this library cannot classify
    engine_unclassified: :unsupported
  }

  @engine_classes Map.new(
                    Enum.map(@engine_input, &{&1, :refused_input}) ++
                      Enum.map(@engine_resource, &{&1, :blocked_resource}) ++
                      Enum.map(@engine_trap, &{&1, :trap}) ++
                      Enum.map(@engine_unsupported, &{&1, :unsupported})
                  )

  # Atoms are created from the closed registry list at compile time, never from engine output.
  @engine_atoms Map.new(@engine_codes, &{&1, String.to_atom(&1)})

  @classes Map.merge(@host_classes, Map.new(@engine_classes, fn {k, v} -> {Map.fetch!(@engine_atoms, k), v} end))
  @codes @classes |> Map.keys() |> Enum.sort()

  @typedoc "Closed set of refusal codes."
  @type code :: atom()
  @typedoc "Closed set of refusal classes."
  @type class :: :refused_input | :refused_identity | :refused_authority | :blocked_resource | :trap | :unsupported
  @typedoc "Caller-visible outcome of a class."
  @type outcome :: :refused | :trap | :unsupported

  @typedoc "A typed refusal."
  @type t :: %__MODULE__{
          code: code(),
          class: class(),
          message: String.t(),
          details: map(),
          raw: map() | nil
        }

  defexception code: nil, class: nil, message: nil, details: %{}, raw: nil

  @doc "Every refusal code, sorted."
  @spec codes() :: [code()]
  def codes, do: @codes

  @doc "The engine's flat error codes, as strings, in registry order."
  @spec engine_codes() :: [String.t()]
  def engine_codes, do: @engine_codes

  @doc "The class of `code`. Raises `ArgumentError` outside the closed set."
  @spec class_of(code()) :: class()
  def class_of(code) do
    case @classes do
      %{^code => class} -> class
      _ -> raise ArgumentError, "unknown refusal code: #{inspect(code)}"
    end
  end

  @doc """
  The outcome of a class or refusal: `:refused`, `:trap` or `:unsupported`.

      iex> AshAffidavit.Refusal.outcome(:trap)
      :trap
      iex> AshAffidavit.Refusal.outcome(AshAffidavit.Refusal.new(:wasm_digest_mismatch))
      :refused
  """
  @spec outcome(class() | t()) :: outcome()
  def outcome(%__MODULE__{class: class}), do: outcome(class)
  def outcome(:trap), do: :trap
  def outcome(:unsupported), do: :unsupported

  def outcome(class) when class in [:refused_input, :refused_identity, :refused_authority, :blocked_resource],
    do: :refused

  @doc """
  Builds a refusal for `code`; `class` comes from the closed table. A missing message defaults
  to the code name. Raises `ArgumentError` outside the closed set.

      iex> AshAffidavit.Refusal.new(:bad_json, "x", %{k: 1}).class
      :refused_input
  """
  @spec new(code(), String.t() | nil, map()) :: t()
  def new(code, message \\ nil, details \\ %{}) when is_map(details) do
    %__MODULE__{
      code: code,
      class: class_of(code),
      message: if(is_binary(message) and message != "", do: message, else: Atom.to_string(code)),
      details: details
    }
  end

  @doc """
  Maps the engine's flat error object (`%{"code" => ..., "message" => ...}` plus any extra
  fields) to a refusal. Extra fields are kept in `:details` and the whole object in `:raw`.
  A code outside the registry becomes `:engine_unclassified`, never a crash.

      iex> r = AshAffidavit.Refusal.from_engine(%{"code" => "too_large", "limit" => "request_bytes"})
      iex> {r.code, r.class, r.details}
      {:too_large, :blocked_resource, %{"limit" => "request_bytes"}}

      iex> AshAffidavit.Refusal.from_engine(%{"code" => "brand_new"}).code
      :engine_unclassified
  """
  @spec from_engine(term()) :: t()
  def from_engine(%{"code" => code} = error) when is_binary(code) do
    details = Map.drop(error, ["code", "message"])

    case @engine_atoms do
      %{^code => atom} ->
        %{new(atom, error["message"], details) | raw: error}

      _ ->
        %{new(:engine_unclassified, "engine returned unknown error code #{inspect(code)}", details) | raw: error}
    end
  end

  def from_engine(other) do
    %{new(:engine_unclassified, "engine error object has no string `code`", %{}) | raw: %{"value" => inspect(other)}}
  end
end
