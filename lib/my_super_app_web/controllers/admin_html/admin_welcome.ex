defmodule MySuperAppWeb.AdminWelcome do
  @moduledoc false
  use MySuperAppWeb, :admin_live_view

  alias MySuperApp.Accounts

  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin Welcome",
       current_user: Accounts.get_user_by_session_token(session["user_token"])
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl">
      <h1 class="mb-8 text-2xl font-semibold text-zinc-900">
        Welcome to the admin area, {@current_user.login}
      </h1>
      <ul class="grid gap-3 sm:grid-cols-2">
        <li :for={section <- admin_sections(@current_user)}>
          <.link
            navigate={section.path}
            class="flex items-center gap-3 rounded-lg border border-zinc-200 bg-white p-4 font-medium text-zinc-900 hover:border-zinc-400"
          >
            <.icon name={section.icon} class="h-5 w-5" /> {section.label}
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end
