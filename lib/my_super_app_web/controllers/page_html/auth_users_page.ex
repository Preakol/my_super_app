defmodule MySuperAppWeb.AuthUsersPage do
  @moduledoc "Public, read-only list of users with search, sorting and paging."
  use MySuperAppWeb, :live_view

  alias MySuperApp.Accounts
  alias MySuperAppWeb.PageHelper

  @sortable [:login, :updated_at]

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Users",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       all_users: Accounts.get_users(),
       filter: "",
       sort: %{column: nil, direction: :asc},
       current_page: 1,
       page_size: 5
     )
     |> refresh_rows()}
  end

  def handle_event("change_filter", %{"filter" => filter}, socket) do
    {:noreply, socket |> assign(filter: filter, current_page: 1) |> refresh_rows()}
  end

  def handle_event("sort", %{"value" => column}, socket) do
    case Enum.find(@sortable, &(Atom.to_string(&1) == column)) do
      nil ->
        {:noreply, socket}

      column ->
        {:noreply,
         socket
         |> assign(sort: PageHelper.toggle_sort(socket.assigns.sort, column))
         |> refresh_rows()}
    end
  end

  def handle_event("change_page_size", %{"value" => value}, socket) do
    case PageHelper.parse_positive(value) do
      {:ok, size} ->
        page = PageHelper.resize_page(socket.assigns.current_page, socket.assigns.page_size, size)
        {:noreply, assign(socket, page_size: size, current_page: page)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("set_page", %{"value" => value}, socket) do
    case PageHelper.parse_positive(value) do
      {:ok, page} ->
        {:noreply,
         assign(socket,
           current_page:
             PageHelper.clamp_page(page, socket.assigns.users, socket.assigns.page_size)
         )}

      :error ->
        {:noreply, socket}
    end
  end

  defp refresh_rows(socket) do
    %{all_users: users, filter: filter, sort: sort} = socket.assigns
    prefix = String.downcase(filter)

    users
    |> Enum.filter(&String.starts_with?(String.downcase(&1.login), prefix))
    |> PageHelper.sort_rows(sort)
    |> then(&assign(socket, users: &1))
  end

  def render(assigns) do
    ~H"""
    <.page_title title="Users" />
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <form
        id="change-filter-form"
        phx-change="change_filter"
        phx-submit="change_filter"
        class="w-full max-w-xs"
      >
        <label for="user-filter" class="sr-only">Search by login</label>
        <input
          id="user-filter"
          type="search"
          name="filter"
          value={@filter}
          placeholder="Search by login"
          phx-debounce="200"
          class="w-full rounded-lg border-zinc-300 text-sm"
        />
      </form>
      <.page_size_select page_size={@page_size} on_change="change_page_size" />
    </div>
    <.data_table
      id="users"
      rows={PageHelper.paginate(@users, @current_page, @page_size)}
      sort={@sort}
      on_sort="sort"
      row_id={&"user-#{&1.id}"}
    >
      <:col :let={user} label="Login" sort_by={:login}>{user.login}</:col>
      <:col :let={user} label="Email">{user.email}</:col>
      <:col :let={user} label="Updated at" sort_by={:updated_at}>
        {format_datetime(user.updated_at)}
      </:col>
    </.data_table>
    <.pagination
      current_page={@current_page}
      total_pages={PageHelper.total_pages(@users, @page_size)}
      on_change="set_page"
    />
    """
  end
end
