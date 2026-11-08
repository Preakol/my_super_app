defmodule MySuperApp.Repo do
  use EctoHooks.Repo,
    otp_app: :my_super_app,
    adapter: Ecto.Adapters.Postgres
end
