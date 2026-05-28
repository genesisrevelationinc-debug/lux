defmodule Lux.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :lux,
      version: "0.5.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        "test.rust": :test,
        docs: :docs
      ],
      aliases: aliases(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      # Package
      description:
        "A framework for building and orchestrating LLM-powered agent workflows in Elixir",
      package: package(),
      # Docs
      name: "Lux",
      source_url: "https://github.com/Spectral-Finance/lux",
      homepage_url: "https://lux.spectrallbas.xyz",
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Lux.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:dev), do: [:logger, :crypto, :wx, :observer, :runtime_tools]
  defp extra_applications(_), do: [:logger, :crypto]

  defp elixirc_paths(:test), do: ["lib", "test/"]
  defp elixirc_paths(_), do: ["lib"]
      {:ex_doc, "~> 0.31", only: :docs, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mimic, "~> 1.7", only: :test},
      {:rustler, "~> 0.32.0", optional: true},
      {:req, "~> 0.5"}
    ]
  end
      "coveralls.detail": "coveralls.detail",
  defp aliases do
    [
      setup: ["deps.get", "cmd --cd priv/lux_rs cargo build --release"],
      "compile.rust": "cmd --cd priv/lux_rs cargo build --release",
      "test.rust": &test_rust/1
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:venomous, "~> 0.7.5"},
      {:crontab, "~> 1.1"},
      {:ex_json_schema, "~> 0.10.2"},
      {:nodejs, "~> 3.1"},
      {:ethers, "~> 0.6.4"},
      {:ex_secp256k1, "~> 0.7.4"},
      {:yaml_elixir, "~> 2.9"},
      {:hammer, "~> 7.0", only: [:test]},
      ]
    ]
  end

  defp test_rust(_args) do
    rust_dir = Path.join(__DIR__, "priv/lux_rs")

    if File.exists?(Path.join(rust_dir, "Cargo.toml")) do
      IO.puts("Running Rust tests...")

      case System.cmd("cargo", ["test", "--workspace"],
             cd: rust_dir,
             stderr_to_stdout: true
           ) do
        {_, 0} ->
          IO.puts("Rust tests passed!")

        {output, status} ->
          IO.puts("Rust tests failed with exit code #{status}:\n#{output}")
          exit({:shutdown, status})
      end
    else
      IO.puts("No Rust code found at #{rust_dir}, skipping Rust tests.")
    end
  end
end
      {:dotenvy, "~> 1.1.0", only: [:dev, :test]},
      {:mock, "~> 0.3.0", only: [:test]},
      {:stream_data, "~> 1.0", only: [:test]},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.integration": :test,
        "test.unit": :test
      ]
    ]
  end

  def package do
    [
      name: "lux",
      description:
        "Lux is a powerful framework for building and orchestrating LLM-powered agent workflows. It provides a robust set of tools for creating, managing, and coordinating AI agents in complex business processes.",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Spectral-Finance/lux",
        "Changelog" => "https://github.com/Spectral-Finance/lux/blob/main/CHANGELOG.md"
      },
      files: [
        "lib",
        "priv/web3/abis/*",
        "priv/python/lux/*.py",
        "priv/python/erlport/*.py",
        "priv/python/hyperliquid_utils/*.py",
        "priv/python/*.py",
        "priv/python/*.toml",
        "priv/python/README.md",
        "priv/node/*.json",
        "priv/node/*.mjs",
        ".formatter.exs",
        "mix.exs",
        "../README.md",
        "LICENSE",
        "CHANGELOG.md"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "../README.md",
        "guides/agents.livemd",
        "guides/beams.livemd",
        "guides/prisms.livemd",
        "guides/signals.livemd",
        "guides/lenses.livemd",
        "guides/language_support.md",
        "guides/language_support/python.livemd",
        "guides/language_support/nodejs.livemd",
        "guides/multi_agent_collaboration.livemd",
        "guides/trading_system.livemd",
        "guides/testing.md",
        "guides/cursor_development.md",
        "guides/contributing.md",
        "guides/troubleshooting.md",
        "guides/getting_started.md",
        "guides/core_concepts.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: Path.wildcard("guides/*.livemd"),
        "Language Support": [
          "guides/language_support.md",
          "guides/language_support/python.livemd",
          "guides/language_support/nodejs.livemd"
        ],
        Setup: [
          "guides/troubleshooting.md",
          "guides/contributing.md"
        ]
      ]
    ]
  end
end
