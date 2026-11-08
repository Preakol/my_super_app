defmodule MySuperAppWeb.Layouts do
  @moduledoc "Root layout plus the public (`app`) and admin (`admin`) LiveView layouts."
  use MySuperAppWeb, :html

  embed_templates "layouts/*"

  attr :current_user, :map, default: nil

  def user_menu(%{current_user: nil} = assigns) do
    ~H"""
    <nav class="flex items-center gap-4 text-sm font-semibold text-zinc-900">
      <.link navigate={~p"/users/register"} class="hover:text-zinc-600">Register</.link>
      <.link navigate={~p"/users/log_in"} class="hover:text-zinc-600">Log in</.link>
    </nav>
    """
  end

  def user_menu(assigns) do
    ~H"""
    <details id="user-menu" class="relative">
      <summary class="flex cursor-pointer list-none items-center gap-2 rounded-full p-1 hover:bg-zinc-100">
        <.avatar user={@current_user} />
        <span class="hidden text-sm font-medium text-zinc-800 sm:inline">
          <%= display_name(@current_user) %>
        </span>
      </summary>
      <ul class="absolute right-0 z-50 mt-2 w-48 rounded-lg border border-zinc-200 bg-white py-1 text-sm shadow-lg">
        <li class="px-4 py-2 text-xs text-zinc-500"><%= display_name(@current_user) %></li>
        <li>
          <.link navigate={~p"/users/settings"} class="block px-4 py-2 hover:bg-zinc-50">
            Settings
          </.link>
        </li>
        <li>
          <.link href={~p"/users/log_out"} method="delete" class="block px-4 py-2 hover:bg-zinc-50">
            Log out
          </.link>
        </li>
      </ul>
    </details>
    """
  end

  defp display_name(%{operator_name: operator} = user) when operator not in [nil, ""],
    do: "#{user.login} (#{operator})"

  defp display_name(user), do: user.login
end
