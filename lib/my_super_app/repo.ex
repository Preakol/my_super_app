defmodule MySuperApp.Repo do
  use Ecto.Repo,
    otp_app: :my_super_app,
    adapter: Ecto.Adapters.Postgres

  use EctoMiddleware.Repo

  # Runs schema hooks such as Post.before_delete/1, which removes the post's
  # picture from Cloudinary.
  @impl EctoMiddleware.Repo
  def middleware(_action, _resource), do: [EctoHooks]
end
