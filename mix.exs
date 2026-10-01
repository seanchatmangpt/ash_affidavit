# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.MixProject do
  @moduledoc false
  use Mix.Project

  @version "26.9.30"
  @name "AshAffidavit"
  @description "Affidavit WASM receipt and process-mining engine for Elixir and Ash: pinned, admitted, typed refusals; grants no authority"
  @github_url "https://github.com/seanchatmangpt/ash_affidavit"

  def project do
    [
      app: :ash_affidavit,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: &docs/0,
      name: @name,
      source_url: @github_url,
      homepage_url: @github_url,
      description: @description
    ]
  end

  def application do
    [
      mod: {AshAffidavit.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  def docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "HANDWRITTEN.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        API: [AshAffidavit, AshAffidavit.Refusal],
        "WASM host (generated)": [
          AshAffidavit.Host,
          AshAffidavit.Pool,
          AshAffidavit.EngineLoad,
          AshAffidavit.WasmConfig,
          AshAffidavit.ABI
        ],
        "Mix tasks": ~r/Mix\.Tasks\.AshAffidavit/
      ]
    ]
  end

  defp package do
    [
      maintainers: ["ash_affidavit contributors"],
      licenses: ["MIT"],
      files:
        ~w(lib priv ontology scripts consumer-pack.pin .formatter.exs mix.exs README.md LICENSE CHANGELOG.md HANDWRITTEN.md),
      links: %{
        "GitHub" => @github_url,
        "Changelog" => "#{@github_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.33 and >= 3.33.11"},
      {:spark, ">= 2.7.0"},
      {:jason, "~> 1.4"},
      {:wasmex, "~> 0.15.1"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end
end
