defmodule MySuperAppWeb.AdminMainPage do
  @moduledoc "Admin user management: filters, role assignment and deletion."
  use MySuperAppWeb, :admin_live_view

  alias MySuperApp.{Accounts, AdminPubSub, Authority, CasinosAdmins, User}
  alias MySuperAppWeb.PageHelper

  @sortable [:id, :login, :email, :updated_at]
  @default_filters %{search: "", operator: nil, role: nil}

  def mount(_params, session, socket) do
    if connected?(socket), do: AdminPubSub.subscribe("users")

    {:ok,
     socket
     |> assign(
       page_title: "Users",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       filters: @default_filters,
       sort: %{column: :id, direction: :asc},
       current_page: 1,
       page_size: 5,
       roles_for_filter: [],
       manage: nil,
       user_to_delete: nil
     )
     |> load_users()}
  end

  @doc """
  Whether `current_user` may change the role of `user`: never their own,
  any user for the super admin, otherwise users without a role or with a
  lower role of the same operator. A missing role (`nil` permissions) sorts
  above every integer, so it counts as the lowest level.
  """
  def can_manage?(current_user, user) do
    user.id != current_user.id and
      (current_user.permissions == 1 or
         ((current_user.operator_id == user.operator_id or is_nil(user.role_id)) and
            user.permissions > current_user.permissions))
  end

  @doc "Whether the delete button is shown for `user`."
  def can_delete?(current_user, user) do
    ((current_user.operator_id == user.operator_id or is_nil(user.role_id)) and
       current_user.permissions < 3 and user.permissions > current_user.permissions and
       user.id != current_user.id) or
      (current_user.permissions == 1 and user.permissions != 2)
  end

  @doc "Admins below level 4 see role/operator columns and row actions."
  def full_view?(current_user), do: current_user.permissions < 4

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}
  def handle_info(:users_updated, socket), do: {:noreply, load_users(socket)}
  def handle_info(:operators_updated, socket), do: {:noreply, load_users(socket)}

  def handle_event("change_search", %{"search" => search}, socket) do
    {:noreply, update_filters(socket, %{socket.assigns.filters | search: search})}
  end

  def handle_event("change_operator_filter", %{"operator" => operator}, socket) do
    operator = blank_to_nil(operator)

    {:noreply,
     socket
     |> assign(
       roles_for_filter:
         if(operator, do: Authority.get_role_names_with_users_by_operator(operator), else: [])
     )
     |> update_filters(%{socket.assigns.filters | operator: operator, role: nil})}
  end

  def handle_event("change_role_filter", %{"role" => role}, socket) do
    {:noreply, update_filters(socket, %{socket.assigns.filters | role: blank_to_nil(role)})}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(sort: %{column: :id, direction: :asc}, roles_for_filter: [])
     |> update_filters(@default_filters)}
  end

  def handle_event("sort", %{"value" => column}, socket) do
    case Enum.find(@sortable, &(Atom.to_string(&1) == column)) do
      nil ->
        {:noreply, socket}

      column ->
        {:noreply,
         socket
         |> assign(sort: PageHelper.toggle_sort(socket.assigns.sort, column))
         |> load_users()}
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

  def handle_event("open_manage", %{"value" => user_id}, socket) do
    with :ok <- authorize_manage(socket.assigns.current_user, user_id),
         %User{} = user <- Accounts.get_user(user_id) do
      current_user = socket.assigns.current_user

      operator =
        if current_user.permissions == 1,
          do: Accounts.get_user_with_op_and_role(user_id).operator_name,
          else: current_user.operator_name

      {:noreply,
       assign(socket,
         manage: %{
           form: user |> Accounts.change_user_role() |> to_form(),
           operator: operator,
           operators: CasinosAdmins.get_operator_names(),
           roles: roles_for_form(operator, current_user.permissions)
         }
       )}
    else
      {:error, message} -> {:noreply, put_flash(socket, :error, message)}
      nil -> {:noreply, put_flash(socket, :error, "User not found")}
    end
  end

  def handle_event("change_manage_operator", %{"operator" => operator}, socket) do
    operator = blank_to_nil(operator)
    roles = roles_for_form(operator, socket.assigns.current_user.permissions)
    {:noreply, update(socket, :manage, &%{&1 | operator: operator, roles: roles})}
  end

  def handle_event("validate_role", %{"user" => params}, socket) do
    form =
      socket.assigns.manage.form.data
      |> Accounts.change_user_role(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, update(socket, :manage, &%{&1 | form: form})}
  end

  def handle_event("save_role", %{"user" => %{"role_id" => role_id}}, socket) do
    %{current_user: current_user, manage: manage} = socket.assigns
    user_id = manage.form.data.id

    with {:ok, role_id} <- PageHelper.parse_positive(role_id),
         :ok <- authorize_manage(current_user, user_id),
         :ok <- authorize_role(manage.roles, role_id),
         {:ok, _user} <- Accounts.update_user_role(user_id, role_id) do
      {:noreply, role_saved(socket, "Role updated")}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Please select a role")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, update(socket, :manage, &%{&1 | form: to_form(changeset)})}

      {:error, message} ->
        {:noreply, socket |> put_flash(:error, message) |> assign(manage: nil)}
    end
  end

  def handle_event("remove_role", _params, socket) do
    user_id = socket.assigns.manage.form.data.id

    with :ok <- authorize_manage(socket.assigns.current_user, user_id),
         {:ok, _user} <- Accounts.remove_user_role(user_id) do
      {:noreply, role_saved(socket, "Role removed")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, update(socket, :manage, &%{&1 | form: to_form(changeset)})}

      {:error, message} ->
        {:noreply, socket |> put_flash(:error, message) |> assign(manage: nil)}
    end
  end

  def handle_event("open_delete", %{"value" => user_id}, socket) do
    {:noreply, assign(socket, user_to_delete: Accounts.get_user(user_id))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, manage: nil, user_to_delete: nil)}
  end

  def handle_event("delete", _params, %{assigns: %{user_to_delete: %User{} = user}} = socket) do
    Process.send_after(self(), :clear_flash, 3000)

    socket =
      case Accounts.delete_user(user.id) do
        {:ok, deleted} ->
          put_flash(socket, :info, "User #{deleted.login} deleted.")

        {:error, _changeset} ->
          put_flash(socket, :error, "User #{user.login} could not be deleted.")
      end

    {:noreply, socket |> assign(user_to_delete: nil) |> load_users()}
  end

  def handle_event("delete", _params, socket), do: {:noreply, assign(socket, user_to_delete: nil)}

  defp authorize_manage(current_user, user_id) do
    case Accounts.get_user_with_op_and_role(user_id) do
      nil ->
        {:error, "User not found"}

      user ->
        if can_manage?(current_user, user),
          do: :ok,
          else: {:error, "You are not allowed to manage this user"}
    end
  end

  defp authorize_role(roles, role_id) do
    if Enum.any?(roles, fn {_name, id} -> id == role_id end),
      do: :ok,
      else: {:error, "This role is not available"}
  end

  defp role_saved(socket, message) do
    Process.send_after(self(), :clear_flash, 3000)

    socket
    |> put_flash(:info, message)
    |> assign(manage: nil, current_page: 1, sort: %{column: :updated_at, direction: :desc})
    |> update_filters(@default_filters)
  end

  defp roles_for_form(nil, _permissions), do: []

  defp roles_for_form(operator, permissions) do
    with_main_admin_role =
      permissions == 1 and is_nil(Accounts.get_main_admin_by_operator(operator))

    operator
    |> Authority.get_roles_by_operator(with_main_admin_role)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp update_filters(socket, filters),
    do: socket |> assign(filters: filters, current_page: 1) |> load_users()

  defp load_users(socket) do
    %{filters: filters, sort: sort} = socket.assigns
    direction = sort.direction |> Atom.to_string() |> String.upcase()
    users = Accounts.get_users_by_filters(Map.put(filters, :sorting, [{sort.column, direction}]))

    assign(socket,
      users: users,
      current_page:
        PageHelper.clamp_page(socket.assigns.current_page, users, socket.assigns.page_size),
      operators_for_filter: CasinosAdmins.get_operator_names_with_users()
    )
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  def render(assigns) do
    ~H"""
    <.page_title title="Users">
      <:actions>
        <.secondary_button phx-click="clear_filters">Clear filters</.secondary_button>
      </:actions>
    </.page_title>

    <div class="mb-4 flex flex-wrap items-center gap-3">
      <form
        id="change-search-form"
        phx-change="change_search"
        phx-submit="change_search"
        class="w-full max-w-xs"
      >
        <label for="admin-user-search" class="sr-only">Search by login or id</label>
        <input
          id="admin-user-search"
          type="search"
          name="search"
          value={@filters.search}
          placeholder="Search by login or id"
          phx-debounce="200"
          class="w-full rounded-lg border-zinc-300 text-sm"
        />
      </form>
      <form id="change-operator-filter-form" phx-change="change_operator_filter">
        <label for="operator-filter" class="sr-only">Operator</label>
        <select id="operator-filter" name="operator" class="rounded-lg border-zinc-300 text-sm">
          <option value="">All operators</option>
          <option :for={op <- @operators_for_filter} value={op} selected={op == @filters.operator}>
            {op}
          </option>
        </select>
      </form>
      <form id="change-role-filter-form" phx-change="change_role_filter">
        <label for="role-filter" class="sr-only">Role</label>
        <select
          id="role-filter"
          name="role"
          disabled={is_nil(@filters.operator)}
          class="rounded-lg border-zinc-300 text-sm disabled:opacity-50"
        >
          <option value="">All roles</option>
          <option :for={role <- @roles_for_filter} value={role} selected={role == @filters.role}>
            {role}
          </option>
        </select>
      </form>
      <div class="ml-auto">
        <.page_size_select page_size={@page_size} on_change="change_page_size" />
      </div>
    </div>

    <.data_table
      id="admin-users"
      rows={PageHelper.paginate(@users, @current_page, @page_size)}
      sort={@sort}
      on_sort="sort"
      row_id={&"user-#{&1.id}"}
    >
      <:col :let={user} label="#" sort_by={:id}>{user.id}</:col>
      <:col :let={user} label="Login" sort_by={:login}>
        {user.login}
        <span :if={user.id == @current_user.id} class="ml-1 rounded bg-zinc-200 px-1.5 text-xs">
          you
        </span>
      </:col>
      <:col :let={user} label="Email" sort_by={:email}>{user.email}</:col>
      <:col :let={user} :if={full_view?(@current_user)} label="Role">
        {user.role_name || "—"}
      </:col>
      <:col :let={user} :if={full_view?(@current_user)} label="Operator">
        {user.operator_name || "—"}
      </:col>
      <:col :let={user} label="Last update" sort_by={:updated_at}>
        {format_datetime(user.updated_at)}
      </:col>
      <:action :let={user} :if={full_view?(@current_user)}>
        <.icon_button
          :if={can_manage?(@current_user, user)}
          icon="hero-key"
          label={"Manage role of #{user.login}"}
          phx-click="open_manage"
          value={user.id}
        />
        <.icon_button
          :if={can_delete?(@current_user, user)}
          icon="hero-trash"
          label={"Delete #{user.login}"}
          phx-click="open_delete"
          value={user.id}
        />
      </:action>
    </.data_table>
    <.pagination
      current_page={@current_page}
      total_pages={PageHelper.total_pages(@users, @page_size)}
      on_change="set_page"
    />

    <.modal :if={@manage} id="manage-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-4 text-lg font-semibold text-zinc-900">Manage user operator and role</h2>
      <form id="change-manage-operator-form" phx-change="change_manage_operator" class="mb-4">
        <label for="manage-operator" class="block text-sm font-semibold text-zinc-800">
          Operator
        </label>
        <select
          id="manage-operator"
          name="operator"
          disabled={@current_user.permissions > 1}
          class="mt-2 w-full rounded-lg border-zinc-300 text-sm disabled:opacity-50"
        >
          <option value="">Select operator</option>
          <option :for={op <- @manage.operators} value={op} selected={op == @manage.operator}>
            {op}
          </option>
        </select>
      </form>
      <.simple_form
        for={@manage.form}
        id="manage-role-form"
        phx-change="validate_role"
        phx-submit="save_role"
      >
        <.input
          field={@manage.form[:role_id]}
          type="select"
          label="Role"
          prompt="Please select role"
          options={@manage.roles}
          disabled={is_nil(@manage.operator)}
        />
        <:actions>
          <div class="flex w-full justify-end gap-2">
            <.secondary_button phx-click="close_modal">Cancel</.secondary_button>
            <%= if is_nil(@manage.form.data.role) do %>
              <.button disabled={!@manage.form.source.valid?}>Give role</.button>
            <% else %>
              <.secondary_button phx-click="remove_role">Remove role</.secondary_button>
              <.button disabled={!@manage.form.source.valid? or @manage.form.source.changes == %{}}>
                Change role
              </.button>
            <% end %>
          </div>
        </:actions>
      </.simple_form>
    </.modal>

    <.confirm_modal
      :if={@user_to_delete}
      id="delete-user-modal"
      title={"Delete user #{@user_to_delete.login}?"}
      on_cancel="close_modal"
      on_confirm="delete"
    />
    """
  end
end
