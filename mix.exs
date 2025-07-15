defmodule Boltx.Mixfile do
  use Mix.Project

  @version "0.0.7"
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
        tool: ExCoveralls,
        summary: [
          threshold: 70
        ]
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
      extra_applications: [:logger, :ssl, :public_key]
    ]
  end

  defp aliases do
    [
      test: [
        "test"
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
        "Luis Sagastume"
      ],
      links: %{
        "Docs" => @url_docs,
        "Github" => @url_github
      }
    }
  end

  defp docs() do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md"]
    ]
  end

  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:db_connection, "~> 2.7.0"},
      {:jason, "~> 1.4", optional: true},
      {:poison, "~> 6.0", optional: true},

      # Testing dependencies
      {:excoveralls, "~> 0.18.0", optional: true, only: [:test, :dev]},
      {:porcelain, "~> 2.0.3", only: [:test, :dev], runtime: false},
      {:uuid, "~> 1.1.8", only: [:test, :dev], runtime: false},
      {:tzdata, "~> 1.1", only: [:test, :dev]},

      # Benchmarking dependencies
      {:benchee, "~> 1.3.0", optional: true, only: [:dev, :test]},
      {:benchee_html, "~> 1.0.0", optional: true, only: [:dev]},

      # Linting dependencies
      {:credo, "~> 1.7.3", only: [:dev]},
      {:dialyxir, "~> 1.4.3", only: [:dev], runtime: false},

      # Documentation dependencies
      # Run me like this: `mix docs`
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
