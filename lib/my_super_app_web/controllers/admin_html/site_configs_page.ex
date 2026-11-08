defmodule MySuperAppWeb.SiteConfigsPage do
  @moduledoc false
  use MySuperAppWeb, :admin_surface_live_view

  alias MySuperApp.{SiteConfigManagement, CasinosAdmins, Accounts, SiteConfig, AdminPubSub}
  alias MySuperAppWeb.PageHelper

  alias MySuperAppWeb.{MyDatepicker, MyFormDropdown, MyDeleteModal}
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
    Dropdown,
    Chip
  }

  alias Moon.Icons.{ControlsChevronLeft, ControlsChevronRight}

  data(config_to_delete, :any, default: %{id: "", brand: ""})
  data(page_title, :string, default: "Site Configs")
  data(current_page, :integer, default: 1)
  data(page_size, :integer, default: 5)
  data(create_modal_open, :boolean, default: false)
  data(del_modal_open, :boolean, default: false)
  data(form, :any, default: to_form(SiteConfigManagement.change_site_config(%SiteConfig{})))
  data(filters, :map, default: %{search: "", start_date: nil, end_date: nil, sorting: [id: "ASC"]})

  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminPubSub.subscribe("site_configs")
    end

    {:ok, assign(socket,
        current_user: Accounts.get_user_by_session_token(session["user_token"]),
        brands_to_choose: get_brands_to_choose()
      )
      |> update_content()
    }
  end

  defp update_content(socket) do
    assign(socket,
      site_configs: SiteConfigManagement.list_site_configs_by_filters(socket.assigns.filters),
      operators_to_choose:
          CasinosAdmins.get_operators()
          |> Enum.map(&%{key: &1.name, value: &1.id})
    )
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:site_configs_updated, socket) do
    {:noreply, update_content(socket)}
  end

  def handle_info(:operators_updated, socket) do
    {:noreply, assign(socket,
      operators_to_choose: CasinosAdmins.get_operators() |> Enum.map(&%{key: &1.name, value: &1.id}))}
  end

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"site_config" => params}, socket) do
    {:noreply, assign(socket, form: validate_form(params))}
  end

  def handle_event("toggle_create_modal", %{"action" => action}, socket) do
    apply(Modal, String.to_atom(action), ["modal_create"])
    {:noreply,
     assign(socket,
       form:
         to_form(
           SiteConfigManagement.change_site_config(%SiteConfig{}, %{
             "operator_id" => socket.assigns.current_user.operator_id
           })
         ),
       create_modal_open: !socket.assigns.create_modal_open
     )}
  end

  def handle_event("create", %{"site_config" => params}, socket) do
    case SiteConfigManagement.create_site_config(params) do
      {:ok, site_config} ->
        Modal.close("modal_create")
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
          socket
          |> put_flash(:info, "Site config for #{site_config.brand} created")
          |> assign(
            create_modal_open: !socket.assigns.create_modal_open,
            current_page: 1,
            filters: %{search: "", start_date: nil, end_date: nil, sorting: [inserted_at: "DESC"]}
          )
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: changeset |> Map.put(:action, :insert) |> to_form())}
    end
  end

  def handle_event("toggle_del_modal", %{"action" => action, "value" => id}, socket) do
    apply(Modal, String.to_atom(action), ["modal_delete"])
    {:noreply,
      assign(socket,
        config_to_delete: SiteConfigManagement.get_site_config(id) || %{id: "", brand: ""},
        del_modal_open: !socket.assigns.del_modal_open
      )
    }
  end

  def handle_event("delete", _params, socket) do
    Modal.close("modal_delete")

    case SiteConfigManagement.delete_site_config(socket.assigns.config_to_delete.id) do
      {:ok, site_config} ->
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
          socket
          |> put_flash(:info, "Site config for #{site_config.brand} deleted")
          |> assign(
            del_modal_open: !socket.assigns.del_modal_open,
            current_page: PageHelper.update_current_page(socket, socket.assigns.site_configs)
          )
        }

      {:error, _} ->
        {:noreply, assign(socket, del_modal_open: !socket.assigns.del_modal_open,
            current_page: PageHelper.update_current_page(socket, socket.assigns.site_configs)
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

  def handle_event("change_status", %{"id" => id, "status" => status}, socket) do
    SiteConfigManagement.update_site_config(id, %{status: status == "false"})
    {:noreply, socket}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply, update_filters(socket, %{search: "", start_date: nil, end_date: nil, sorting: [id: "ASC"]})}
  end

  def handle_event("handle_sorting_click", %{"sort-dir" => dir, "sort-key" => key}, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :sorting, ["#{key}": dir]))}
  end

  def handle_event("change_search", %{"value" => search}, socket) do
    {:noreply, update_filters(socket,  Map.put(socket.assigns.filters, :search, search))}
  end

  def handle_event("change_date_filter", %{"value" => ""}, socket) do
    {:noreply, update_filters(socket, Map.merge(socket.assigns.filters, %{start_date: nil, end_date: nil}))}
  end

  def handle_event("change_date_filter", %{"value" => date}, %{assigns: %{filters: %{start_date: nil}}} = socket) do
    {:noreply, assign(socket, filters: Map.merge(socket.assigns.filters, %{start_date: date}))}
  end

  def handle_event("change_date_filter", %{"value" => date}, %{assigns: %{filters: %{start_date: _, end_date: nil}}} = socket) do
    {:noreply, update_filters(socket, set_start_end_dates(socket.assigns.filters, date))}
  end

  def handle_event("change_date_filter", %{"value" => date}, socket) do
    {:noreply, assign(socket, filters: Map.merge(socket.assigns.filters, %{start_date: date, end_date: nil}))}
  end

  defp set_start_end_dates(%{start_date: start_date} = filters, end_date) do
    Map.merge(filters, %{start_date: min(start_date, end_date), end_date: max(start_date, end_date)})
  end

  defp validate_form(params) do
    SiteConfigManagement.change_site_config(%SiteConfig{}, params)
    |> to_form()
  end

  defp update_filters(socket, new_filters) do
    assign(
      socket,
      filters: new_filters,
      site_configs: SiteConfigManagement.list_site_configs_by_filters(new_filters)
    )
  end

  defp get_brands_to_choose() do
    existing_brands = SiteConfigManagement.get_existing_brands()

    SiteConfigManagement.list_potential_brands()
    |> Enum.map(fn brand ->
      %{key: brand, value: brand, disabled: Enum.member?(existing_brands, brand)}
    end)
  end
end
