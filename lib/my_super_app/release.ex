defmodule MySuperApp.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :my_super_app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seeds the demo data on a running release, e.g.
  `bin/my_super_app rpc "MySuperApp.Release.seed()"`. The demo accounts get
  the password from `SEED_PASSWORD`, so a public deployment never ships
  with a known default.
  """
  def seed do
    case System.fetch_env("SEED_PASSWORD") do
      {:ok, password} when byte_size(password) >= 12 ->
        {:ok, result} = MySuperApp.StartData.run(password)
        IO.puts("Demo data: #{result}")

      _missing_or_short ->
        raise "set SEED_PASSWORD (at least 12 characters) before seeding"
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
