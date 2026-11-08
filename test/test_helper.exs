Mox.defmock(MySuperApp.CloudinaryMock, for: MySuperApp.Cloudinary)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MySuperApp.Repo, :manual)
{:ok, _} = Application.ensure_all_started(:ex_machina)
Faker.start()
