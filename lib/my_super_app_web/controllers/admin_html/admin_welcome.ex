defmodule MySuperAppWeb.AdminWelcome do
  @moduledoc false
  
  use MySuperAppWeb, :admin_surface_live_view

  alias MySuperApp.Accounts

  alias Moon.Design.Button

  data(page_title, :string, default: "Admin Welcome")

  def mount(_params, session, socket) do
    {
      :ok,
      assign(
        socket,
        current_user: Accounts.get_user_by_session_token(session["user_token"])
      )
    }
  end
end
