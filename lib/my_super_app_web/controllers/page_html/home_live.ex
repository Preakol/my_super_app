defmodule MySuperAppWeb.HomeLive do
  @moduledoc false
  use MySuperAppWeb, :live_view

  alias MySuperApp.Accounts

  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       page_title: "Home",
       current_user: Accounts.get_user_by_session_token(session["user_token"])
     )}
  end

  def render(assigns) do
    ~H"""
    <section class="py-10">
      <h1 class="text-3xl font-bold tracking-tight text-zinc-900">MySuperApp</h1>
      <p class="mt-3 max-w-xl text-zinc-600">
        A Phoenix LiveView blog platform with an admin back-office: posts with tags and
        pictures, users, roles, operators and site configuration.
      </p>
      <div class="mt-6 flex flex-wrap gap-3">
        <%= if @current_user do %>
          <.link :if={@current_user.permissions} navigate={~p"/admin"}>
            <.button>Open admin</.button>
          </.link>
          <.link navigate={~p"/users/settings"}>
            <.secondary_button>Account settings</.secondary_button>
          </.link>
        <% else %>
          <.link navigate={~p"/users/log_in"}>
            <.button>Log in</.button>
          </.link>
          <.link navigate={~p"/users/register"}>
            <.secondary_button>Create an account</.secondary_button>
          </.link>
        <% end %>
        <.link navigate={~p"/users"}>
          <.secondary_button>Browse users</.secondary_button>
        </.link>
      </div>
    </section>
    """
  end
end
