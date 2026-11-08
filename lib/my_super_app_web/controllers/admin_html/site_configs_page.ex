defmodule MySuperAppWeb.SiteConfigsPage do
  @moduledoc "Site configurations per operator: create, pause/resume, delete."
  use MySuperAppWeb, :admin_live_view

  alias MySuperApp.{Accounts, AdminPubSub, CasinosAdmins, SiteConfig, SiteConfigManagement}
  alias MySuperAppWeb.PageHelper

  @sortable [:id, :inserted_at]
  @default_filters %{search: "", start_date: nil, end_date: nil}

  def mount(_params, session, socket) do
    if connected?(socket), do: AdminPubSub.subscribe("site_configs")

    {:ok,
     socket
     |> assign(
       page_title: "Site Configs",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       filters: @default_filters,
       sort: %{column: :id, direction: :asc},
       current_page: 1,
       page_size: 5,
       create_form: nil,
       config_to_delete: nil
     )
     |> load_configs()}
  end

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}
  def handle_info(:site_configs_updated, socket), do: {:noreply, load_configs(socket)}
  def handle_info(:operators_updated, socket), do: {:noreply, load_configs(socket)}

  def handle_event("change_search", %{"search" => search}, socket) do
    {:noreply, update_filters(socket, %{socket.assigns.filters | search: search})}
  end

  def handle_event("change_dates", %{"start_date" => start_date, "end_date" => end_date}, socket) do
    {:noreply,
     update_filters(socket, %{socket.assigns.filters | start_date: start_date, end_date: end_date})}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket |> assign(sort: %{column: :id, direction: :asc}) |> update_filters(@default_filters)}
  end

  def handle_event("sort", %{"value" => column}, socket) do
    case Enum.find(@sortable, &(Atom.to_string(&1) == column)) do
      nil ->
        {:noreply, socket}

      column ->
        {:noreply,
         socket
         |> assign(sort: PageHelper.toggle_sort(socket.assigns.sort, column))
         |> load_configs()}
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
             PageHelper.clamp_page(page, socket.assigns.site_configs, socket.assigns.page_size)
         )}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_status", %{"value" => id}, socket) do
    case SiteConfigManagement.get_site_config(id) do
      %SiteConfig{} = config ->
        case SiteConfigManagement.update_site_config(config.id, %{status: !config.status}) do
          {:ok, _config} ->
            {:noreply, load_configs(socket)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Status could not be changed")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Site config not found")}
    end
  end

  def handle_event("open_create", _params, socket) do
    form =
      %SiteConfig{}
      |> SiteConfigManagement.change_site_config(%{
        "operator_id" => socket.assigns.current_user.operator_id
      })
      |> to_form()

    {:noreply, assign(socket, create_form: form)}
  end

  def handle_event("validate", %{"site_config" => params}, socket) do
    form =
      %SiteConfig{}
      |> SiteConfigManagement.change_site_config(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_form: form)}
  end

  def handle_event("create", %{"site_config" => params}, socket) do
    case SiteConfigManagement.create_site_config(params) do
      {:ok, config} ->
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
         socket
         |> put_flash(:info, "Site config for #{config.brand} created")
         |> assign(create_form: nil, sort: %{column: :inserted_at, direction: :desc})
         |> update_filters(@default_filters)}

      {:error, changeset} ->
        {:noreply, assign(socket, create_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("open_delete", %{"value" => id}, socket) do
    {:noreply, assign(socket, config_to_delete: SiteConfigManagement.get_site_config(id))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, create_form: nil, config_to_delete: nil)}
  end

  def handle_event(
        "delete",
        _params,
        %{assigns: %{config_to_delete: %SiteConfig{} = config}} = socket
      ) do
    Process.send_after(self(), :clear_flash, 3000)

    socket =
      case SiteConfigManagement.delete_site_config(config.id) do
        {:ok, _config} ->
          put_flash(socket, :info, "Site config for #{config.brand} deleted")

        {:error, _changeset} ->
          put_flash(socket, :error, "Site config for #{config.brand} could not be deleted")
      end

    {:noreply, socket |> assign(config_to_delete: nil) |> load_configs()}
  end

  def handle_event("delete", _params, socket),
    do: {:noreply, assign(socket, config_to_delete: nil)}

  defp update_filters(socket, filters),
    do: socket |> assign(filters: filters, current_page: 1) |> load_configs()

  defp load_configs(socket) do
    %{filters: filters, sort: sort} = socket.assigns

    {start_date, end_date} =
      case PageHelper.date_range(filters.start_date, filters.end_date) do
        {from, to} -> {from, to}
        :none -> {nil, nil}
      end

    direction = sort.direction |> Atom.to_string() |> String.upcase()

    configs =
      SiteConfigManagement.list_site_configs_by_filters(%{
        search: filters.search,
        start_date: start_date,
        end_date: end_date,
        sorting: [{sort.column, direction}]
      })

    assign(socket,
      site_configs: configs,
      current_page:
        PageHelper.clamp_page(socket.assigns.current_page, configs, socket.assigns.page_size),
      operators: Enum.map(CasinosAdmins.get_operators(), &{&1.name, &1.id}),
      brands: brand_options()
    )
  end

  defp brand_options do
    taken = MapSet.new(SiteConfigManagement.get_existing_brands())

    Enum.map(
      SiteConfigManagement.list_potential_brands(),
      &[key: &1, value: &1, disabled: MapSet.member?(taken, &1)]
    )
  end

  def render(assigns) do
    ~H"""
    <.page_title title="Site Configs">
      <:actions>
        <.secondary_button phx-click="clear_filters">Clear filters</.secondary_button>
        <.button phx-click="open_create">Add site config</.button>
      </:actions>
    </.page_title>

    <div class="mb-4 flex flex-wrap items-center gap-3">
      <form
        id="change-search-form"
        phx-change="change_search"
        phx-submit="change_search"
        class="w-full max-w-sm"
      >
        <label for="config-search" class="sr-only">Search</label>
        <input
          id="config-search"
          type="search"
          name="search"
          value={@filters.search}
          placeholder="Search by site id, brand or operator"
          phx-debounce="200"
          class="w-full rounded-lg border-zinc-300 text-sm"
        />
      </form>
      <.date_range_filter
        start_date={@filters.start_date}
        end_date={@filters.end_date}
        on_change="change_dates"
      />
      <div class="ml-auto">
        <.page_size_select page_size={@page_size} on_change="change_page_size" />
      </div>
    </div>

    <.data_table
      id="site-configs"
      rows={PageHelper.paginate(@site_configs, @current_page, @page_size)}
      sort={@sort}
      on_sort="sort"
      row_id={&"site-config-#{&1.id}"}
    >
      <:col :let={config} label="#" sort_by={:id}>{config.id}</:col>
      <:col :let={config} label="Brand">{config.brand}</:col>
      <:col :let={config} label="Operator">{config.operator_name}</:col>
      <:col :let={config} label="Created at" sort_by={:inserted_at}>
        {format_datetime(config.inserted_at)}
      </:col>
      <:col :let={config} label="Status">
        <span class={[
          "rounded-full px-2 py-0.5 text-xs font-semibold",
          if(config.status, do: "bg-emerald-100 text-emerald-800", else: "bg-zinc-200 text-zinc-700")
        ]}>
          {if config.status, do: "ACTIVE", else: "STOPPED"}
        </span>
      </:col>
      <:action :let={config}>
        <.icon_button
          icon={if config.status, do: "hero-pause", else: "hero-play"}
          label={if config.status, do: "Stop #{config.brand}", else: "Start #{config.brand}"}
          phx-click="toggle_status"
          value={config.id}
        />
        <.icon_button
          icon="hero-trash"
          label={"Delete #{config.brand}"}
          phx-click="open_delete"
          value={config.id}
        />
      </:action>
    </.data_table>
    <.pagination
      current_page={@current_page}
      total_pages={PageHelper.total_pages(@site_configs, @page_size)}
      on_change="set_page"
    />

    <.modal :if={@create_form} id="create-config-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-2 text-lg font-semibold text-zinc-900">Create new site config</h2>
      <.simple_form
        for={@create_form}
        id="create-config-form"
        phx-change="validate"
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
          field={@create_form[:brand]}
          type="select"
          label="Brand"
          prompt="Please select brand"
          options={@brands}
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

    <.confirm_modal
      :if={@config_to_delete}
      id="delete-config-modal"
      title={"Delete site config for #{@config_to_delete.brand}?"}
      on_cancel="close_modal"
      on_confirm="delete"
    />
    """
  end
end
