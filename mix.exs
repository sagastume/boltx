defmodule Boltx.Mixfile do
  use Mix.Project

  @version "0.0.1"
  @url_docs "https://hexdocs.pm/boltx"
  @url_github "https://github.com/sagastume/boltx"

  def project do
    [
      app: :boltx,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: "Neo4j driver for Elixir, using the fast Bolt protocol",
      name: "Boltx",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      dialyzer: [plt_add_apps: [:jason, :poison, :mix], ignore_warnings: ".dialyzer_ignore.exs"],
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        bench: :bench,
        credo: :dev,
        boltx: :test,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.travis": :test
      ],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [ :logger ]
    ]
  end

  defp aliases do
    [
      test: [
        "test --only core"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    %{
      files: [
        "lib",
        "mix.exs",
        "LICENSE"
      ],
      licenses: ["Apache 2.0"],
      maintainers: [
        "Luis Sagastume",
      ],
      links: %{
        "Docs" => @url_docs,
        "Github" => @url_github
      }
    }
  end

  defp docs do
    [
      name: "Boltx",
      logo: "assets/boltx_white_transparent.png",
      assets: "assets",
      source_ref: "v#{@version}",
      source_url: @url_github,
      main: "Boltx",
      extra_section: "guides",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "docs/getting-started.md",
        "docs/features/configuration.md",
        "docs/features/using-cypher.md",
        "docs/features/using-temporal-and-spatial-types.md",
        "docs/features/about-transactions.md",
        "docs/features/about-encoding.md",
        "docs/features/routing.md",
        "docs/features/multi-tenancy.md",
        "docs/features/using-with-phoenix.md"
      ]
    ]
  end

  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:db_connection, "~> 2.4.2"},
      {:jason, "~> 1.4", optional: true},
      {:poison, "~> 5.0", optional: true},

      # Testing dependencies
      {:excoveralls, "~> 0.15.0", optional: true, only: [:test, :dev]},
      {:mix_test_watch, "~> 1.1.0", only: [:dev, :test]},
      {:porcelain, "~> 2.0.3", only: [:test, :dev], runtime: false},
      {:uuid, "~> 1.1.8", only: [:test, :dev], runtime: false},
      {:tzdata, "~> 1.1", only: [:test, :dev]},

      # Benchmarking dependencies
      {:benchee, "~> 1.1.0", optional: true, only: [:dev, :test]},
      {:benchee_html, "~> 1.0.0", optional: true, only: [:dev]},

      # Linting dependencies
      {:credo, "~> 1.6.7", only: [:dev]},
      {:dialyxir, "~> 1.2.0", only: [:dev], runtime: false},

      # Documentation dependencies
      # Run me like this: `mix docs`
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
