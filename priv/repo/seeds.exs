# Local demo data: `mix run priv/repo/seeds.exs` (also run by `mix ecto.setup`).
# All demo accounts share one password, "demo-password" unless SEED_PASSWORD is set.
password = System.get_env("SEED_PASSWORD", "demo-password")

case MySuperApp.StartData.run(password) do
  {:ok, :seeded} -> IO.puts("Seeded demo data. Log in as admin@example.com / #{password}")
  {:ok, :skipped} -> IO.puts("Database already has users, skipping demo data")
end
