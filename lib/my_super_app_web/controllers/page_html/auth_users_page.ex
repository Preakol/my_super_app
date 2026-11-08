defmodule MySuperAppWeb.AuthUsersPage do
  @moduledoc false
  use MySuperAppWeb, :surface_live_view

  alias MySuperApp.Accounts
  alias Moon.Design.{Table, Pagination, Search, Dropdown, Chip}
  alias Moon.Design.Table.Column
  alias Moon.Icons.{ControlsChevronRightSmall, ControlsChevronLeftSmall}

  prop(selected, :list, default: nil)
  data(user, :any, default: %{id: "", login: "", email: ""})
  data(users, :any, default: [])

  def mount(_params, session, socket) do
    user = MySuperApp.Accounts.get_user_by_session_token(session["user_token"])
    
    {:ok, assign(socket,
        current_user: user,
        users: Accounts.get_users(),
        selected: nil,
        current_page: 1,
        page_size: 5,
        sort: [updated_at: "DEFAULT"],
        filter: ""
      )
    }
  end

  def handle_event("on_change_page_size", %{"value" => page_size}, socket) do
    Dropdown.close("page-size-dropdown")

    current_page_size = socket.assigns.page_size

    updated_socket =
      case page_size |> String.to_integer() do
        ^current_page_size ->
          socket
        10 ->
          assign(socket,
            page_size: page_size |> String.to_integer(),
            current_page: ceil(socket.assigns.current_page / 2)
          )
        5 ->
          assign(socket, page_size: page_size |> String.to_integer())
      end

    {:noreply, updated_socket}
  end

  def handle_event("change_filter", %{"value" => filter}, socket) do
    {:noreply,
     assign(socket,
       filter: filter,
       users:
         Enum.filter(Accounts.get_users(), fn b -> String.starts_with?(String.downcase(b.login), [String.downcase(filter)]) end),
       current_page: 1
     )}
  end

  def handle_event("set_current_page", %{"value" => page}, socket) do
    {:noreply, assign(socket, current_page: String.to_integer(page))}
  end

  def handle_event(
        "on_sorting_click",
        %{"sort-dir" => sort_dir, "sort-key" => sort_key},
        socket
      ) do
    {:noreply,
     assign(socket,
       users: users_sorted_by(Accounts.get_users(), String.to_atom(sort_key), sort_dir),
       sort: ["#{sort_key}": sort_dir]
     )}
  end

  def users_sorted_by(users, col, dir) do
    case dir do
      "DEFAULT" ->
        Accounts.get_users()

      "ASC" ->
        users
        |> Enum.sort_by(&[&1[col]], :asc)

      "DESC" ->
        users
        |> Enum.sort_by(&[&1[col]], :desc)

      _ -> users
    end
  end

  defp users_page(assigns) do
    assigns.users
    |> Enum.slice((assigns.current_page * assigns.page_size - assigns.page_size)..(assigns.current_page * assigns.page_size - 1))
  end
end
