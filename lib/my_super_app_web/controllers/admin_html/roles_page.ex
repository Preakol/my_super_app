defmodule MySuperAppWeb.RolesPage do
  @moduledoc "Create, edit and delete operator roles."
  use MySuperAppWeb, :admin_live_view

  alias MySuperApp.{Accounts, AdminPubSub, Authority, CasinosAdmins, Role}
  alias MySuperAppWeb.PageHelper

  @sortable [:id, :name, :updated_at]
  @permission_options [{"Viewer", 4}, {"Gamechanger", 3}]
  @default_sort %{column: :updated_at, direction: :desc}

  def mount(_params, session, socket) do
    if connected?(socket), do: AdminPubSub.subscribe("roles")

    {:ok,
     socket
     |> assign(
       page_title: "Roles",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       operator_filter: "All",
       sort: @default_sort,
       current_page: 1,
       page_size: 5,
       permission_options: @permission_options,
       create_form: nil,
       edit_form: nil,
       confirm_delete: false
     )
     |> load_roles()}
  end

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}
  def handle_info(:roles_updated, socket), do: {:noreply, load_roles(socket)}
  def handle_info(:operators_updated, socket), do: {:noreply, load_roles(socket)}

  def handle_event("change_operator_filter", %{"operator" => operator}, socket) do
    {:noreply, socket |> assign(operator_filter: operator, current_page: 1) |> load_roles()}
  end

  def handle_event("sort", %{"value" => column}, socket) do
    case Enum.find(@sortable, &(Atom.to_string(&1) == column)) do
      nil ->
        {:noreply, socket}

      column ->
        {:noreply,
         socket
         |> assign(sort: PageHelper.toggle_sort(socket.assigns.sort, column))
         |> load_roles()}
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
             PageHelper.clamp_page(page, socket.assigns.roles, socket.assigns.page_size)
         )}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("open_create", _params, socket) do
    form =
      %Role{}
      |> Authority.change_role(%{"operator_id" => socket.assigns.current_user.operator_id})
      |> to_form()

    {:noreply, assign(socket, create_form: form)}
  end

  def handle_event("validate_create", %{"role" => attrs}, socket) do
    {:noreply, assign(socket, create_form: validate(%Role{}, attrs))}
  end

  def handle_event("create", %{"role" => attrs}, socket) do
    case Authority.create_role(attrs) do
      {:ok, _role} ->
        {:noreply, saved(socket, "Role created")}

      {:error, changeset} ->
        {:noreply, assign(socket, create_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("open_edit", %{"value" => id}, socket) do
    case Authority.get_role(id) do
      %Role{} = role ->
        {:noreply, assign(socket, edit_form: role |> Authority.change_role() |> to_form())}

      nil ->
        {:noreply, put_flash(socket, :error, "Role not found")}
    end
  end

  def handle_event("validate_edit", %{"role" => attrs}, socket) do
    {:noreply, assign(socket, edit_form: validate(socket.assigns.edit_form.data, attrs))}
  end

  def handle_event("update", %{"role" => attrs}, socket) do
    case Authority.update_role(socket.assigns.edit_form.data.id, attrs) do
      {:ok, _role} ->
        {:noreply, saved(socket, "Role updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset, action: :update))}
    end
  end

  def handle_event("ask_delete", _params, socket),
    do: {:noreply, assign(socket, confirm_delete: true)}

  def handle_event("cancel_delete", _params, socket),
    do: {:noreply, assign(socket, confirm_delete: false)}

  def handle_event("delete", _params, socket) do
    Process.send_after(self(), :clear_flash, 3000)

    socket =
      case Authority.delete_role(socket.assigns.edit_form.data.id) do
        {:ok, _role} -> put_flash(socket, :info, "Role deleted")
        {:error, _changeset} -> put_flash(socket, :error, "Role could not be deleted")
      end

    {:noreply, socket |> assign(edit_form: nil, confirm_delete: false) |> load_roles()}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, create_form: nil, edit_form: nil, confirm_delete: false)}
  end

  defp saved(socket, message) do
    Process.send_after(self(), :clear_flash, 3000)

    socket
    |> put_flash(:info, message)
    |> assign(
      create_form: nil,
      edit_form: nil,
      operator_filter: "All",
      sort: @default_sort,
      current_page: 1
    )
    |> load_roles()
  end

  defp validate(role, attrs),
    do: role |> Authority.change_role(attrs) |> to_form(action: :validate)

  defp load_roles(socket) do
    %{operator_filter: operator, sort: sort} = socket.assigns
    direction = sort.direction |> Atom.to_string() |> String.upcase()

    roles =
      Authority.get_roles_by_filters(%{operator: operator, sorting: [{sort.column, direction}]})

    assign(socket,
      roles: roles,
      current_page:
        PageHelper.clamp_page(socket.assigns.current_page, roles, socket.assigns.page_size),
      operators: Enum.map(CasinosAdmins.get_operators(), &{&1.name, &1.id})
    )
  end

  def render(assigns) do
    ~H"""
    <.page_title title="Roles">
      <:actions>
        <.button phx-click="open_create">Add new role</.button>
      </:actions>
    </.page_title>

    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <form id="change-operator-filter-form" phx-change="change_operator_filter">
        <label for="roles-operator-filter" class="sr-only">Operator</label>
        <select id="roles-operator-filter" name="operator" class="rounded-lg border-zinc-300 text-sm">
          <option value="All" selected={@operator_filter == "All"}>All operators</option>
          <option :for={{name, _id} <- @operators} value={name} selected={name == @operator_filter}>
            <%= name %>
          </option>
        </select>
      </form>
      <.page_size_select page_size={@page_size} on_change="change_page_size" />
    </div>

    <.data_table
      id="roles"
      rows={PageHelper.paginate(@roles, @current_page, @page_size)}
      sort={@sort}
      on_sort="sort"
      row_id={&"role-#{&1.id}"}
    >
      <:col :let={role} label="#" sort_by={:id}><%= role.id %></:col>
      <:col :let={role} label="Name" sort_by={:name}><%= role.name %></:col>
      <:col :let={role} label="Operator"><%= role.operator_name %></:col>
      <:col :let={role} label="Last update" sort_by={:updated_at}>
        <%= format_datetime(role.updated_at) %>
      </:col>
      <:action :let={role}>
        <.icon_button
          :if={role.permissions != 2}
          icon="hero-pencil-square"
          label={"Edit #{role.name}"}
          phx-click="open_edit"
          value={role.id}
        />
      </:action>
    </.data_table>
    <.pagination
      current_page={@current_page}
      total_pages={PageHelper.total_pages(@roles, @page_size)}
      on_change="set_page"
    />

    <.modal :if={@create_form} id="create-role-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-2 text-lg font-semibold text-zinc-900">Create new role</h2>
      <.simple_form
        for={@create_form}
        id="create-role-form"
        phx-change="validate_create"
        phx-submit="create"
      >
        <%= if @current_user.permissions > 1 do %>
          <input
            type="hidden"
            name={@create_form[:operator_id].name}
            value={@create_form[:operator_id].value}
          />
          <.input
            name="operator_display"
            value={@create_form[:operator_id].value}
            type="select"
            label="Operator"
            options={@operators}
            disabled
          />
        <% else %>
          <.input
            field={@create_form[:operator_id]}
            type="select"
            label="Operator"
            prompt="Please select operator"
            options={@operators}
          />
        <% end %>
        <.input
          field={@create_form[:name]}
          label="Name"
          placeholder="Role name"
          disabled={@create_form[:operator_id].value in [nil, ""]}
        />
        <.input
          field={@create_form[:permissions]}
          type="select"
          label="Permission"
          prompt="Please select permission"
          options={@permission_options}
          disabled={@create_form[:operator_id].value in [nil, ""]}
        />
        <:actions>
          <div class="flex w-full justify-end gap-2">
            <.secondary_button phx-click="close_modal">Cancel</.secondary_button>
            <.button disabled={!@create_form.source.valid?}>Create</.button>
          </div>
        </:actions>
      </.simple_form>
    </.modal>

    <.modal
      :if={@edit_form && !@confirm_delete}
      id="edit-role-modal"
      show
      on_cancel={JS.push("close_modal")}
    >
      <h2 class="mb-2 text-lg font-semibold text-zinc-900">Update role</h2>
      <.simple_form
        for={@edit_form}
        id="edit-role-form"
        phx-change="validate_edit"
        phx-submit="update"
      >
        <.input field={@edit_form[:name]} label="Name" placeholder="Role name" />
        <.input
          field={@edit_form[:permissions]}
          type="select"
          label="Permission"
          options={@permission_options}
        />
        <:actions>
          <div class="flex w-full justify-end gap-2">
            <.secondary_button phx-click="ask_delete" class="text-red-700">Delete</.secondary_button>
            <.secondary_button phx-click="close_modal">Close</.secondary_button>
            <.button disabled={!@edit_form.source.valid? or @edit_form.source.changes == %{}}>
              Update
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </.modal>

    <.confirm_modal
      :if={@edit_form && @confirm_delete}
      id="delete-role-modal"
      title={"Delete role #{@edit_form.data.name}?"}
      on_cancel="cancel_delete"
      on_confirm="delete"
    />
    """
  end
end
