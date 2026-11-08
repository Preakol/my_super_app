import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

config :my_super_app, Oban, testing: :manual

config :my_super_app, :mail_from, "my-super-app@example.com"

config :my_super_app, :cloudinary_client, MySuperApp.CloudinaryMock

config :my_super_app, MySuperApp.Cloudinary.Client,
  api_key: "test-api-key",
  secret: "test-api-secret",
  cloud_name: "test-cloud"

config :my_super_app, :cloudinary_req_options, plug: {Req.Test, MySuperApp.Cloudinary.Client}

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :my_super_app, MySuperApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "my_super_app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :my_super_app, MySuperAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "slUNqxkLkVNsGq+r6o/cw4aClpMN4ejHx5AYOx1eDAve3TSlWEYO0LTOtYLNg8+M",
  server: false

# In test we don't send emails.
config :my_super_app, MySuperApp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
