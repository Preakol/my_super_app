defmodule MySuperAppWeb.Router do
  use MySuperAppWeb, :router

  import MySuperAppWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MySuperAppWeb.Layouts, :main}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MySuperAppWeb do
    pipe_through [:browser, :store_last_path]

    live("/", HomeLive)
    live("/users", AuthUsersPage)
  end

  scope "/", MySuperAppWeb do
    pipe_through [:browser, :require_authenticated_user, :store_last_path]

    live("/users/settings", UsersSettingsPage)
  end

  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MySuperAppWeb.Layouts, :admin}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :store_last_path
  end

  scope "/admin", MySuperAppWeb do
    pipe_through [:admin, :require_authenticated_user, :require_permission_to_admin_page]

    live("/", AdminWelcome)
    live("/users", AdminMainPage)
    live("/posts", PostsPage)
    live("/pictures", PicturesPage)
  end

  scope "/admin", MySuperAppWeb do
    pipe_through [:admin, :require_authenticated_user, :require_permission_to_operators_page]

    live("/operators", OperatorsPage)
  end

  scope "/admin", MySuperAppWeb do
    pipe_through [:admin, :require_authenticated_user, :require_permission_to_roles_and_site_page]

    live("/roles", RolesPage)
    live("/site-configs", SiteConfigsPage)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:my_super_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MySuperAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MySuperAppWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{MySuperAppWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", MySuperAppWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end

  scope "/api", MySuperAppWeb do
    pipe_through :api

    get "/pictures/by_post/:post_id", PictureController, :show_by_post
    resources "/pictures", PictureController, only: [:index, :show, :create, :update, :delete]

    get "/users/by_email/:email", UserController, :show
    get "/users/by_name/:name", UserController, :show
    resources "/users", UserController, only: [:index, :show, :create, :update, :delete]

    resources "/configs", SiteConfigController, only: [:index, :show, :create, :update, :delete]

    get "/roles/by_user/:user_id", RoleController, :show
    resources "/roles", RoleController, only: [:index, :show, :create, :update, :delete]

    resources "/posts", PostController, only: [:index, :show, :create, :update, :delete]
    resources "/tags", TagController, only: [:index, :show, :create, :update, :delete]
  end
end
