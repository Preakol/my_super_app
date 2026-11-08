defmodule MySuperAppWeb.OperatorsPage do
  @moduledoc "Super-admin page for creating and deleting operators."
  use MySuperAppWeb, :admin_live_view

  alias MySuperApp.{Accounts, AdminPubSub, CasinosAdmins, Operator}
  alias MySuperAppWeb.PageHelper

  @sortable [:id, :name, :inserted_at]

  def mount(_params, session, socket) do
    if connected?(socket), do: AdminPubSub.subscribe("operators")

    {:ok,
     socket
     |> assign(
       page_title: "Operators",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       sort: %{column: :id, direction: :asc},
       current_page: 1,
       page_size: 5,
       create_form: nil,
       operator_to_delete: nil
     )
     |> load_operators()}
  end

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}
  def handle_info(:operators_updated, socket), do: {:noreply, load_operators(socket)}

  def handle_info(:users_updated, socket),
    do: {:noreply, assign(socket, users_to_choose: users_to_choose())}

  def handle_event("open_create", _params, socket) do
    {:noreply, assign(socket, create_form: operator_form(%{}))}
  end

  def handle_event("validate", %{"operator" => params}, socket) do
    {:noreply, assign(socket, create_form: operator_form(params, :validate))}
  end

  def handle_event("create", %{"operator" => params}, socket) do
    case CasinosAdmins.create_operator(params) do
      {:ok, _operator} ->
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
         socket
         |> put_flash(:info, "Operator created")
         |> assign(
           create_form: nil,
           current_page: 1,
           sort: %{column: :inserted_at, direction: :desc}
         )
         |> load_operators()}

      {:error, changeset} ->
        {:noreply, assign(socket, create_form: to_form(changeset))}
    end
  end

  def handle_event("open_delete", %{"value" => id}, socket) do
    {:noreply, assign(socket, operator_to_delete: CasinosAdmins.get_operator(id))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, create_form: nil, operator_to_delete: nil)}
  end

  def handle_event(
        "delete",
        _params,
        %{assigns: %{operator_to_delete: %{id: id, name: name}}} = socket
      ) do
    Process.send_after(self(), :clear_flash, 3000)

    socket =
      case CasinosAdmins.delete_operator(id) do
        {:ok, _operator} -> put_flash(socket, :info, "#{name} deleted")
        {:error, _changeset} -> put_flash(socket, :error, "#{name} could not be deleted")
      end

    {:noreply, socket |> assign(operator_to_delete: nil) |> load_operators()}
  end

  def handle_event("delete", _params, socket),
    do: {:noreply, assign(socket, operator_to_delete: nil)}

  def handle_event("sort", %{"value" => column}, socket) do
    case Enum.find(@sortable, &(Atom.to_string(&1) == column)) do
      nil ->
        {:noreply, socket}

      column ->
        {:noreply,
         socket
         |> assign(sort: PageHelper.toggle_sort(socket.assigns.sort, column))
         |> load_operators()}
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
             PageHelper.clamp_page(page, socket.assigns.operators, socket.assigns.page_size)
         )}

      :error ->
        {:noreply, socket}
    end
  end

  defp load_operators(socket) do
    operators = CasinosAdmins.get_operators() |> PageHelper.sort_rows(socket.assigns.sort)

    assign(socket,
      operators: operators,
      current_page:
        PageHelper.clamp_page(socket.assigns.current_page, operators, socket.assigns.page_size),
      users_to_choose: users_to_choose()
    )
  end

  defp operator_form(params, action \\ nil) do
    %Operator{}
    |> Operator.changeset(params)
    |> Map.put(:action, action)
    |> to_form()
  end

  defp users_to_choose, do: Enum.map(Accounts.get_users_without_role(), &{&1.login, &1.id})

  defp can_submit?(form), do: form.source.valid? and form.params["user_id"] not in [nil, ""]

  def render(assigns) do
    ~H"""
    <.page_title title="Operators">
      <:actions>
        <.button phx-click="open_create">Add new operator</.button>
      </:actions>
    </.page_title>

    <div class="mb-4 flex justify-end">
      <.page_size_select page_size={@page_size} on_change="change_page_size" />
    </div>

    <.data_table
      id="operators"
      rows={PageHelper.paginate(@operators, @current_page, @page_size)}
      sort={@sort}
      on_sort="sort"
      row_id={&"operator-#{&1.id}"}
    >
      <:col :let={operator} label="#" sort_by={:id}><%= operator.id %></:col>
      <:col :let={operator} label="Name" sort_by={:name}><%= operator.name %></:col>
      <:col :let={operator} label="Created at" sort_by={:inserted_at}>
        <%= format_datetime(operator.inserted_at) %>
      </:col>
      <:action :let={operator}>
        <.icon_button
          icon="hero-trash"
          label={"Delete #{operator.name}"}
          phx-click="open_delete"
          value={operator.id}
        />
      </:action>
    </.data_table>
    <.pagination
      current_page={@current_page}
      total_pages={PageHelper.total_pages(@operators, @page_size)}
      on_change="set_page"
    />

    <.modal :if={@create_form} id="create-operator-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-2 text-lg font-semibold text-zinc-900">Create new operator</h2>
      <.simple_form
        for={@create_form}
        id="create-operator-form"
        phx-change="validate"
        phx-submit="create"
      >
        <.input field={@create_form[:name]} label="Name" placeholder="Operator name" />
        <.input
          field={@create_form[:user_id]}
          type="select"
          label="Head of the operator"
          prompt="Select a user without a role"
          options={@users_to_choose}
          disabled={@create_form.params["name"] in [nil, ""]}
        />
        <:actions>
          <div class="flex w-full justify-end gap-2">
            <.secondary_button phx-click="close_modal">Cancel</.secondary_button>
            <.button disabled={!can_submit?(@create_form)}>Create</.button>
          </div>
        </:actions>
      </.simple_form>
    </.modal>

    <.confirm_modal
      :if={@operator_to_delete}
      id="delete-operator-modal"
      title={"Delete operator #{@operator_to_delete.name}?"}
      on_cancel="close_modal"
      on_confirm="delete"
    />
    """
  end
end
