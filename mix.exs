defmodule MySuperApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_super_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: false],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: Mix.compilers() ++ [:surface]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {MySuperApp.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17.5"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:petal_components, "~> 1.0"},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:moon, "~> 2.81"},
      {:surface, "0.11.4"},
      {:faker, "~> 0.18"},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:pbkdf2_elixir, "~> 2.0"},
      {:tzdata, "~> 1.1"},
      {:cloudex, "~> 1.4"},
      {:flashy, "~> 0.2"},
      {:ecto_hooks, "~> 1.2"},
      {:sendgrid, "~> 2.0"},
      {:oban, "~> 2.17"}
    ]
  end
  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build", "ecto.reset"],
      "assets.build": ["cmd --cd assets npm run build", "esbuild default"],
      "assets.setup": ["cmd --cd assets npm i", "cmd --cd deps/moon/assets npm i", "esbuild.install --if-missing"],
      "assets.deploy": [
        "assets.setup",
        "assets.build",
        "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "phx.digest"],
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"]
    ]
  end
end
