defmodule MySuperAppWeb.RolesPage do
  @moduledoc false
  use MySuperAppWeb, :admin_surface_live_view

  alias MySuperApp.{Accounts, Authority, CasinosAdmins, Role, AdminPubSub}
  alias MySuperAppWeb.{PageHelper, MyDeleteModal}

  alias Moon.Icons.{ControlsChevronLeft, ControlsChevronRight}
  alias Moon.Design.{
    Form,
    Form.Field,
    Form.Input,
    Modal,
    Button,
    Button.IconButton,
    Pagination,
    Table,
    Table.Column,
    Drawer,
    Dropdown,
    Chip
  }

  data(page_title, :string, default: "Roles")
  data(drawer_update_open, :boolean, default: false)
  data(create_modal_open, :boolean, default: false)
  data(del_modal_open, :boolean, default: false)
  data(form_update, :any, default: Authority.change_role(%Role{}) |> to_form())
  data(filters, :map, default: %{operator: "All", sorting: [updated_at: "DESC"]})
  data(page_size, :integer, default: 5)
  data(current_page, :integer, default: 1)

  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminPubSub.subscribe("roles")
    end

    current_user = Accounts.get_user_by_session_token(session["user_token"])

    {:ok, assign(socket,
        current_user: current_user,
        form_create:
          %Role{}
          |> Authority.change_role(%{"operator_id" => current_user.operator_id})
          |> to_form()
      )
      |> update_content()
    }
  end

  defp update_content(socket) do
    assign(socket,
      roles: Authority.get_roles_by_filters(socket.assigns.filters),
      operators_to_choose: CasinosAdmins.get_operators() |> Enum.map(&%{key: &1.name, value: &1.id})
    )
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:roles_updated, socket) do
    {:noreply, update_content(socket)}
  end

  def handle_info(:operators_updated, socket) do
    {:noreply, assign(socket,
      operators_to_choose: CasinosAdmins.get_operators() |> Enum.map(&%{key: &1.name, value: &1.id}))}
  end

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_create_modal", %{"action" => action}, socket) do
    apply(Modal, String.to_atom(action), ["modal_create"])
    {:noreply, assign(socket, create_modal_open: !socket.assigns.create_modal_open)}
  end

  def handle_event("validate_create", %{"role" => attrs}, socket) do
    {:noreply, assign(socket, form_create: validate_form(socket.assigns.form_create.data, attrs))}
  end

  def handle_event("create_role", %{"role" => attrs}, socket) do
    case Authority.create_role(attrs) do
      {:ok, _role} ->
        Modal.close("modal_create")
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
          put_flash(socket, :info, "role created")
          |> assign(
            form_create:
              %Role{}
              |> Authority.change_role(%{"operator_id" => socket.assigns.current_user.operator_id})
              |> to_form(),
            create_modal_open: false,
            current_page: 1,
            filters: %{operator: "All", sorting: [updated_at: "DESC"]}
          )
        }

      {:error, changeset} ->
        {:noreply, assign(socket, form_create: Map.put(changeset, :action, :insert) |> to_form())}
    end
  end

  def handle_event("drawer_update_open", %{"value" => id}, socket) do
    Drawer.open("drawer_update")

    {:noreply,
      assign(socket,
        form_update:
          Authority.get_role(id)
          |> Authority.change_role()
          |> to_form,
        drawer_update_open: true
    )}
  end

  def handle_event("validate_update", %{"role" => attrs}, socket) do
    {:noreply,
      assign(socket,
        form_update:
          socket.assigns.form_update.data
          |> validate_form(Map.update!(attrs, "permissions", &String.to_integer(&1)))
      )
    }
  end

  def handle_event("update", %{"role" => role_attrs}, socket) do
    case Authority.update_role(socket.assigns.form_update.data.id, role_attrs) do
      {:ok, _role} ->
        Drawer.close("drawer_update")
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
          put_flash(socket, :info, "role updated")
          |> assign(drawer_update_open: false,
            current_page: 1,
            filters: %{operator: "All", sorting: [updated_at: "DESC"]}
          )
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form_update: Map.put(changeset, :action, :insert) |> to_form)}
    end
  end

  def handle_event("drawer_close", _, socket) do
    Drawer.close("drawer_update")
    {:noreply, assign(socket, drawer_update_open: false)}
  end

  def handle_event("toggle_del_modal", _, socket) do
    {:noreply, assign(socket, del_modal_open: !socket.assigns.del_modal_open)}
  end

  def handle_event("delete", _, socket) do
    Modal.close("modal_delete")
    Drawer.close("drawer_update")
    Process.send_after(self(), :clear_flash, 3000)

    case Authority.delete_role(socket.assigns.form_update.data.id) do
      {:ok, _role} ->
        {:noreply,
          put_flash(socket, :info, "role deleted")
          |> assign(drawer_update_open: false,
            del_modal_open: false,
            current_page: PageHelper.update_current_page(socket, socket.assigns.roles)
          )
          |> update_content()
        }

      {:error, _} ->
        {:noreply, assign(socket, drawer_update_open: false,
            del_modal_open: false,
            current_page: PageHelper.update_current_page(socket, socket.assigns.roles)
          )
          |> update_content()
        }
    end
  end

  def handle_event("set_current_page", %{"value" => page}, socket) do
    {:noreply, assign(socket, current_page: String.to_integer(page))}
  end

  def handle_event("on_change_page_size", %{"value" => page_size}, socket) do
    Dropdown.close("page-size-dropdown")
    {:noreply, assign(socket, PageHelper.change_page_size(socket, String.to_integer(page_size)))}
  end

  def handle_event("change_operator_filter", %{"value" => operator}, socket) do
    Dropdown.close("filter-operator-dropdown")
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :operator, operator))}
  end

  def handle_event("handle_sorting_click", %{"sort-dir" => dir, "sort-key" => key}, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :sorting, ["#{key}": dir]))}
  end

  defp update_filters(socket, new_filters) do
    assign(
      socket,
      filters: new_filters,
      roles: Authority.get_roles_by_filters(new_filters)
    )
  end

  defp validate_form(data, role_attrs) do
    Authority.change_role(data, role_attrs)
    |> Map.put(:action, :insert)
    |> to_form()
  end
end
