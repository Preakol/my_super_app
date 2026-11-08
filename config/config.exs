# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :my_super_app, Oban,
  repo: MySuperApp.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, email: 5]

config :my_super_app, :cloudinary_client, MySuperApp.Cloudinary.Client
config :my_super_app, :cloudinary_folder, to_string(config_env())

config :my_super_app,
  ecto_repos: [MySuperApp.Repo],
  generators: [timestamp_type: :utc_datetime]

config :esbuild,
  version: "0.25.0",
  my_super_app: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures the endpoint
config :my_super_app, MySuperAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MySuperAppWeb.ErrorHTML, json: MySuperAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MySuperApp.PubSub,
  live_view: [signing_salt: "/3+Q+WrQ"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :my_super_app, MySuperApp.Mailer, adapter: Swoosh.Adapters.Local

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  my_super_app: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
