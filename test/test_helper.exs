Mox.defmock(MySuperApp.CloudinaryMock, for: MySuperApp.Cloudinary)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MySuperApp.Repo, :manual)
