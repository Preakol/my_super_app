defmodule MySuperAppWeb.AdminMainPage do
  @moduledoc false
  use MySuperAppWeb, :admin_surface_live_view

  alias MySuperApp.{Accounts, Authority, CasinosAdmins, User, AdminPubSub}
  alias MySuperAppWeb.{PageHelper, MyDeleteModal, AdminMainPage.Table}

  alias Moon.Icons.{ControlsChevronLeft, ControlsChevronRight, ControlsChevronDown}
  alias Moon.Design.{
    Form,
    Form.Field,
    Form.Input,
    Modal,
    Button,
    Button.IconButton,
    Pagination,
    Dropdown,
    Chip
  }

  data(user_to_delete, :map, default: %{login: ""})
  data(page_title, :string, default: "Users")
  data(current_page, :integer, default: 1)
  data(page_size, :integer, default: 5)
  data(manage_modal_open, :boolean, default: false)
  data(del_modal_open, :boolean, default: false)
  data(form_manage, :any, default: to_form(Accounts.change_user_role(%User{})))
  data(filters, :map, default: %{search: "", operator: "Select Operator", role: "Select Role", sorting: [id: "ASC"]})
  data(roles_for_form, :list, default: [])
  data(roles_for_filter, :list, default: [])
  data(operators_for_form, :list, default: [])
  data(operator_in_form, :string, default: "")

  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminPubSub.subscribe("users")
    end

    {:ok,
      assign(socket, current_user: MySuperApp.Accounts.get_user_by_session_token(session["user_token"]))
      |> update_content()}
  end

  defp update_content(socket) do
    assign(socket,
      users: Accounts.get_users_by_filters(socket.assigns.filters),
      operators_for_filter: CasinosAdmins.get_operator_names_with_users()
    )
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:users_updated, socket) do
    {:noreply, update_content(socket)}
  end

  def handle_info(:operators_updated, socket) do
    {:noreply, assign(socket, operators_for_filter: CasinosAdmins.get_operator_names_with_users())}
  end

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_del_modal", %{"action" => action, "value" => user_id}, socket) do
    apply(Modal, String.to_atom(action), ["modal_delete"])
    {:noreply,
     assign(socket,
       user_to_delete: Accounts.get_user(user_id) || %{id: "", login: "", email: "", role_id: ""},
       del_modal_open: !socket.assigns.del_modal_open
     )}
  end

  def handle_event("delete", _, socket) do
    Modal.close("modal_delete")

    case Accounts.delete_user(socket.assigns.user_to_delete.id) do
      {:ok, user} ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply,
          socket
          |> put_flash(:info, "User #{user.login} deleted.")
          |> assign(
            del_modal_open: !socket.assigns.del_modal_open,
            current_page: PageHelper.update_current_page(socket, socket.assigns.users)
          )
        }

      {:error, _} ->
        {:noreply,
          assign(socket,
            del_modal_open: !socket.assigns.del_modal_open,
            current_page: PageHelper.update_current_page(socket, socket.assigns.users)
          ) |> update_content()
        }
    end
  end

  def handle_event("modal_manage_open", %{"value" => user_id}, socket) do
    Modal.open("modal_manage")

    operator_name =
      case socket.assigns.current_user.permissions do
        1 ->
          Accounts.get_user_with_op_and_role(user_id).operator_name

        _ ->
          socket.assigns.current_user.operator_name
      end

    {:noreply,
      assign(socket,
        operator_in_form: operator_name,
        roles_for_form: get_roles_for_form(operator_name, socket.assigns.current_user.permissions),
        operators_for_form: CasinosAdmins.get_operator_names(),
        form_manage:
          Accounts.get_user(user_id)
          |> Accounts.change_user_role()
          |> to_form(),
        manage_modal_open: !socket.assigns.manage_modal_open
     )}
  end

  def handle_event("modal_manage_close", _, socket) do
    Modal.close("modal_manage")
    {:noreply, assign(socket, manage_modal_open: !socket.assigns.manage_modal_open)}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    {:noreply, assign(socket, form_manage: validate_form(socket.assigns.form_manage.data, params))}
  end

  def handle_event("change_operator_form", %{"value" => operator_name}, socket) do
    {:noreply,
      assign(socket,
        roles_for_form: get_roles_for_form(operator_name, socket.assigns.current_user.permissions),
        operator_in_form: operator_name
      )
    }
  end

  def handle_event("manage", %{"user" => user_attrs}, socket) do
    socket.assigns.form_manage.data.id
    |> Accounts.update_user_role(String.to_integer(user_attrs["role_id"]))
    |> case do
      {:ok, _user} ->
        Process.send_after(self(), :clear_flash, 3000)
        Modal.close("modal_manage")

        {:noreply,
          socket
          |> put_flash(:info, "role updated")
          |> assign(
            manage_modal_open: !socket.assigns.manage_modal_open,
            current_page: 1,
            filters: %{search: "", operator: "Select Operator", role: "Select Role", sorting: [updated_at: "DESC"]}
          )
        }

      {:error, changeset} ->
        {:noreply, assign(socket, form_manage: to_form(changeset), val_disabled: false)}
    end
  end

  def handle_event("on_remove_role", _params, socket) do
    case Accounts.remove_user_role(socket.assigns.form_manage.data.id) do
      {:ok, _user} ->
        Process.send_after(self(), :clear_flash, 3000)
        Modal.close("modal_manage")

        {:noreply,
          socket
          |> put_flash(:info, "role removed")
          |> assign(
            manage_modal_open: !socket.assigns.manage_modal_open,
            current_page: 1,
            filters: %{search: "", operator: "Select Operator", role: "Select Role", sorting: [updated_at: "DESC"]}
          )
        }

      {:error, changeset} ->
        {:noreply, assign(socket, form_manage: to_form(changeset))}
    end
  end

  def handle_event("on_change_page_size", %{"value" => page_size}, socket) do
    Dropdown.close("page-size-dropdown")
    {:noreply, assign(socket, PageHelper.change_page_size(socket, String.to_integer(page_size)))}
  end

  def handle_event("set_current_page", %{"value" => page}, socket) do
    {:noreply, assign(socket, current_page: String.to_integer(page))}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply, update_filters(socket, %{search: "", operator: "Select Operator", role: "Select Role", sorting: [id: "ASC"]})}
  end

  def handle_event("handle_sorting_click", %{"sort-dir" => dir, "sort-key" => key}, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :sorting, ["#{key}": dir]))}
  end

  def handle_event("change_operator_filter", %{"value" => operator}, socket) do
    {:noreply,
      update_filters(socket, Map.merge(socket.assigns.filters, %{operator: operator, role: "Select Role"}))
      |> assign(roles_for_filter: Authority.get_role_names_with_users_by_operator(operator))
    }
  end

  def handle_event("change_role_filter", %{"value" => role}, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :role, role))}
  end

  def handle_event("change_search", %{"value" => search}, socket) do
    {:noreply, update_filters(socket,  Map.put(socket.assigns.filters, :search, search))}
  end

  defp get_roles_for_form(operator_name, permission) do
    operator_name
    |> Authority.get_roles_by_operator(permission == 1 and is_nil(Accounts.get_main_admin_by_operator(operator_name)))
    |> Enum.map(&%{key: &1.name, value: &1.id})
  end

  defp update_filters(socket, new_filters) do
    assign(
      socket,
      filters: new_filters,
      users: Accounts.get_users_by_filters(new_filters)
    )
  end

  defp validate_form(data, user_attrs) do
    Accounts.change_user_role(data, user_attrs)
    |> Map.put(:action, :insert)
    |> to_form()
  end
end
