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
  @docs_url "https://hexdocs.pm/ash_affidavit"
  @maintainer "Sean Chatman <xpointsh@gmail.com>"

  def project do
    [
      app: :ash_affidavit,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() == :prod,
      dialyzer: dialyzer(),
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

  # Dialyzer baseline. :mix is in the PLT because the mix tasks call Mix.* directly; :ex_unit because
  # test/support modules reference ExUnit callbacks. Residual suppressions live in .dialyzer_ignore.exs and
  # list_unused_filters turns a stale entry into a failure.
  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      flags: [:no_opaque, :no_match],
      plt_local_path: "priv/plts",
      ignore_warnings: ".dialyzer_ignore.exs",
      list_unused_filters: true
    ]
  end

  # Tasks that chain through test-only modules default to :test so no MIX_ENV export is needed.
  def cli do
    [
      preferred_envs: [
        credo: :test,
        dialyzer: :test,
        sobelow: :test,
        "spark.formatter": :test,
        "spark.cheat_sheets": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: extras(),
      extra_section: "GUIDES",
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        Topics: ~r'documentation/topics',
        "DSL Reference": ~r'documentation/dsls',
        "About AshAffidavit": [
          "AGENTS.md",
          "HANDWRITTEN.md",
          "CHANGELOG.md",
          "LICENSE",
          "usage-rules.md",
          ~r'usage-rules/'
        ]
      ],
      groups_for_modules: [
        API: [AshAffidavit, AshAffidavit.Refusal],
        "Ash extension": [
          AshAffidavit.Resource,
          AshAffidavit.Resource.Info,
          AshAffidavit.Dsl.Runtime,
          AshAffidavit.Dsl.Operation,
          AshAffidavit.Resource.Persist,
          AshAffidavit.Resource.Verify,
          AshAffidavit.Formatter,
          AshAffidavit.Change.Receipt,
          AshAffidavit.Validation.Verified,
          AshAffidavit.Calculation.Verdict,
          AshAffidavit.Type.Receipt,
          AshAffidavit.Type.ChainHash,
          AshAffidavit.Notifier,
          AshAffidavit.Error.Refused
        ],
        "WASM host (generated)": [
          AshAffidavit.Host,
          AshAffidavit.Pool,
          AshAffidavit.EngineLoad,
          AshAffidavit.WasmConfig,
          AshAffidavit.ABI
        ],
        "Mix tasks": ~r/Mix\.Tasks\.AshAffidavit/,
        Other: ~r/.*/
      ]
    ]
  end

  # Extras in reading order. Single files are filtered through File.exists?/1 and directories use
  # Path.wildcard/1 so a new page under documentation/ is picked up without editing this file.
  defp extras do
    existing([{"README.md", title: "Home"}, "usage-rules.md"]) ++
      Path.wildcard("usage-rules/*.md") ++
      Path.wildcard("documentation/tutorials/*.md") ++
      Path.wildcard("documentation/topics/*.md") ++
      Path.wildcard("documentation/dsls/*.md") ++
      existing(["AGENTS.md", "HANDWRITTEN.md", "CHANGELOG.md", "LICENSE"])
  end

  defp existing(entries) do
    Enum.filter(entries, fn
      {path, _opts} -> File.exists?(path)
      path -> File.exists?(path)
    end)
  end

  defp package do
    [
      maintainers: [@maintainer],
      licenses: ["MIT"],
      files:
        ~w(lib priv/affidavit ontology scripts consumer-pack.pin .formatter.exs mix.exs AGENTS.md usage-rules.md usage-rules README* LICENSE* LICENSES REUSE.toml HANDWRITTEN.md CHANGELOG* documentation),
      links: %{
        "GitHub" => @github_url,
        "Documentation" => @docs_url,
        "Changelog" => "#{@github_url}/blob/main/CHANGELOG.md",
        "REUSE Compliance" => "https://api.reuse.software/info/github.com/seanchatmangpt/ash_affidavit"
      }
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.33 and >= 3.33.11"},
      {:spark, ">= 2.7.0"},
      # Error.Refused is a Splode error; splode arrives through ash and is declared for the direct use.
      {:splode, "~> 0.3"},
      {:jason, "~> 1.4"},
      {:wasmex, "~> 0.15.1"},
      {:telemetry, "~> 1.0"},
      # Optional: only the `mix ash_affidavit.install` task needs it, and only in the consuming project.
      {:igniter, ">= 0.6.29 and < 1.0.0-0", optional: true},
      {:ex_doc, "~> 0.38", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.6", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 1.2", only: :dev}
    ]
  end

  defp aliases do
    [
      format: "format --migrate",
      credo: "credo --strict",
      sobelow: "sobelow --skip",
      "spark.formatter": "spark.formatter --extensions AshAffidavit.Resource",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshAffidavit.Resource",
      docs: ["spark.cheat_sheets", "docs"]
    ]
  end
end
