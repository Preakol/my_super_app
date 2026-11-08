defmodule MySuperAppWeb.OperatorsPage do
  @moduledoc false
  use MySuperAppWeb, :admin_surface_live_view

  alias MySuperApp.{CasinosAdmins, Operator, Accounts, AdminPubSub}
  alias MySuperAppWeb.{PageHelper, MyDeleteModal}

  alias Moon.Design.{
    Table,
    Table.Column,
    Button,
    Button.IconButton,
    Form,
    Form.Field,
    Form.Input,
    Modal,
    Chip,
    Pagination,
    Dropdown
  }

  alias Moon.Icons.{ControlsChevronLeft, ControlsChevronRight}

  data(operator_to_delete, :any, default: %{name: ""})
  data(page_title, :string, default: "Operators")
  data(page_size, :integer, default: 5)
  data(current_page, :integer, default: 1)
  data(sort, :any, default: [id: "ASC"])
  data(create_modal_open, :boolean, default: false)
  data(del_modal_open, :boolean, default: false)

  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminPubSub.subscribe("operators")
    end

    {:ok, assign(socket,
        current_user: Accounts.get_user_by_session_token(session["user_token"]),
        form_create: to_form(Operator.changeset(%Operator{}, %{}))
      )
      |> update_content()
    }
  end

  defp update_content(%{assigns: %{sort: [{sort_key, sort_dir}]}} = socket) do
    assign(socket,
      operators:
        CasinosAdmins.get_operators()
        |> PageHelper.sort_by_collumn(sort_key, sort_dir),
      users_to_choose: get_users_to_choose()
    )
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:operators_updated, socket) do
    {:noreply, update_content(socket)}
  end

  def handle_info(:users_updated, socket) do
    {:noreply, assign(socket, users_to_choose: get_users_to_choose())}
  end

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_create_modal", _params, socket) do
    {:noreply,
     assign(socket,
       create_modal_open: !socket.assigns.create_modal_open
     )}
  end

  def handle_event("validate", %{"operator" => operator_attrs}, socket) do
    {:noreply, assign(socket, form_create: validate_form(operator_attrs))}
  end

  def handle_event("create", %{"operator" => operator_params}, socket) do
    Modal.close("modal_create")

    case CasinosAdmins.create_operator(operator_params) do
      {:ok, _operator} ->
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
          socket
          |> put_flash(:info, "operator created")
          |> assign(
            create_modal_open: !socket.assigns.create_modal_open,
            current_page: 1,
            sort: [inserted_at: "DESC"],
            form_create:
              %Operator{}
              |> Operator.changeset(%{})
              |> to_form()
          )
        }

      {:error, changeset} ->
        {:noreply, assign(socket, form_create: to_form(changeset))}
    end
  end

  def handle_event("toggle_del_modal", %{"action" => action, "value" => operator_id}, socket) do
    apply(Modal, String.to_atom(action), ["modal_delete"])
    {:noreply,
     assign(socket,
       del_modal_open: !socket.assigns.del_modal_open,
       operator_to_delete: CasinosAdmins.get_operator(operator_id) || %{id: "", name: ""}
     )}
  end

  def handle_event("delete", _, socket) do
    Modal.close("modal_delete")

    case CasinosAdmins.delete_operator(socket.assigns.operator_to_delete.id) do
      {:ok, operator} ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply,
          socket
          |> put_flash(:info, "#{operator.name} deleted")
          |> assign(current_page: PageHelper.update_current_page(socket, socket.assigns.operators))
        }

      {:error, _} ->
        {:noreply,
          assign(socket, current_page: PageHelper.update_current_page(socket, socket.assigns.operators))
          |> update_content()}
    end
  end

  def handle_event(
        "handle_sorting_click",
        %{"sort-dir" => sort_dir, "sort-key" => sort_key},
        socket
      ) do
    {:noreply,
     assign(socket,
       operators:
         PageHelper.sort_by_collumn(
           socket.assigns.operators,
           String.to_atom(sort_key),
           sort_dir
         ),
       sort: ["#{sort_key}": sort_dir]
     )}
  end

  def handle_event("on_change_page_size", %{"value" => page_size}, socket) do
    Dropdown.close("page-size-dropdown")
    {:noreply, assign(socket, PageHelper.change_page_size(socket, String.to_integer(page_size)))}
  end

  defp get_users_to_choose() do
    Accounts.get_users_without_role()
    |> Enum.map(&%{key: &1.login, value: &1.id |> Integer.to_string()})
  end

  defp validate_form(operator_attrs) do
    %Operator{}
    |> Operator.changeset(operator_attrs)
    |> Map.put(:action, :insert)
    |> to_form()
  end
end
