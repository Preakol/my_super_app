defmodule MySuperAppWeb.AdminComponents do
  @moduledoc """
  Small HEEx function components shared by the admin pages: navigation,
  avatars, filters, sorting, pagination and confirmation dialogs.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: MySuperAppWeb.Endpoint,
    router: MySuperAppWeb.Router,
    statics: MySuperAppWeb.static_paths()

  import MySuperAppWeb.CoreComponents, only: [icon: 1, modal: 1, button: 1]

  alias Phoenix.LiveView.JS

  @doc """
  Admin sections the user may open. Mirrors the router's permission plugs:
  operators need permission level 1, roles and site configs need level < 3.
  """
  def admin_sections(user) do
    [
      %{label: "Users", path: ~p"/admin/users", icon: "hero-users", visible?: true},
      %{label: "Posts", path: ~p"/admin/posts", icon: "hero-newspaper", visible?: true},
      %{label: "Pictures", path: ~p"/admin/pictures", icon: "hero-photo", visible?: true},
      %{
        label: "Operators",
        path: ~p"/admin/operators",
        icon: "hero-building-office",
        visible?: user.permissions == 1
      },
      %{label: "Roles", path: ~p"/admin/roles", icon: "hero-key", visible?: user.permissions < 3},
      %{
        label: "Site Configs",
        path: ~p"/admin/site-configs",
        icon: "hero-cog-6-tooth",
        visible?: user.permissions < 3
      }
    ]
    |> Enum.filter(& &1.visible?)
  end

  attr :user, :map, required: true
  attr :class, :string, default: "h-8 w-8"

  def avatar(%{user: %{avatar_image: url}} = assigns) when url not in [nil, ""] do
    ~H"""
    <img
      src={@user.avatar_image}
      alt={"#{@user.login} avatar"}
      class={["rounded-full object-cover", @class]}
    />
    """
  end

  def avatar(assigns) do
    ~H"""
    <span class={[
      "flex items-center justify-center rounded-full bg-zinc-800 text-sm font-semibold text-white",
      @class
    ]}>
      {@user.login |> String.first() |> String.upcase()}
    </span>
    """
  end

  attr :title, :string, required: true
  slot :actions

  def page_title(assigns) do
    ~H"""
    <div class="mb-6 flex flex-wrap items-center justify-between gap-3 border-b border-zinc-200 pb-4">
      <h1 class="text-2xl font-semibold text-zinc-900">{@title}</h1>
      <div class="flex flex-wrap items-center gap-2">{render_slot(@actions)}</div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :on_cancel, :string, required: true, doc: "event pushed when the dialog is dismissed"
  attr :on_confirm, :string, required: true, doc: "event pushed when the user confirms"
  attr :confirm_label, :string, default: "Delete"

  def confirm_modal(assigns) do
    ~H"""
    <.modal id={@id} show on_cancel={JS.push(@on_cancel)}>
      <h2 class="text-lg font-semibold text-zinc-900">{@title}</h2>
      <div class="mt-6 flex justify-end gap-2">
        <.secondary_button phx-click={@on_cancel}>Cancel</.secondary_button>
        <.button id={"#{@id}-confirm"} phx-click={@on_confirm} class="bg-red-600 hover:bg-red-700">
          {@confirm_label}
        </.button>
      </div>
    </.modal>
    """
  end

  attr :type, :string, default: "button"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled value)
  slot :inner_block, required: true

  def secondary_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm font-semibold text-zinc-900",
        "hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :published, :boolean, required: true
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(value)

  def publish_toggle(assigns) do
    ~H"""
    <button
      type="button"
      role="switch"
      aria-checked={to_string(@published)}
      disabled={@disabled}
      title={if @disabled, do: "Posts can be (un)published 5 minutes after the last change"}
      class={[
        "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition",
        "disabled:cursor-not-allowed disabled:opacity-50",
        if(@published,
          do: "border-emerald-600 bg-emerald-50 text-emerald-800",
          else: "border-zinc-300 bg-white text-zinc-700"
        )
      ]}
      {@rest}
    >
      <span class={[
        "h-2.5 w-2.5 rounded-full",
        if(@published, do: "bg-emerald-600", else: "bg-zinc-400")
      ]} />
      {if @published, do: "Published", else: "Not Published"}
    </button>
    """
  end

  attr :tag, :map, required: true, doc: "a map with :title and :color, or string keys"
  slot :inner_block

  def tag_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold text-white",
      tag_color(@tag)
    ]}>
      {tag_title(@tag)} {render_slot(@inner_block)}
    </span>
    """
  end

  defp tag_title(%{title: title}), do: title
  defp tag_title(%{"title" => title}), do: title

  defp tag_color(tag), do: tag |> Map.get(:color, Map.get(tag, "color")) |> color_class()

  @tag_colors %{
    "bg-piccolo" => "bg-indigo-600",
    "bg-hit" => "bg-sky-600",
    "bg-popo" => "bg-violet-600",
    "bg-krillin" => "bg-amber-500",
    "bg-chichi" => "bg-pink-600",
    "bg-roshi" => "bg-emerald-600",
    "bg-dodoria" => "bg-red-600",
    "bg-cell" => "bg-lime-600",
    "bg-whis" => "bg-blue-600",
    "bg-frieza" => "bg-purple-600"
  }

  @doc """
  Maps the colour names stored on tags (originally Moon design tokens) to
  Tailwind classes, so existing rows keep their colour without a migration.
  """
  def color_class(color), do: Map.get(@tag_colors, color, "bg-zinc-600")

  attr :options, :list, required: true
  attr :sort_by, :string, required: true
  attr :direction, :atom, required: true, values: [:asc, :desc]
  attr :on_change, :string, required: true
  attr :on_toggle, :string, required: true

  def sort_control(assigns) do
    ~H"""
    <form id={"#{@on_change}-form"} phx-change={@on_change} class="flex items-center">
      <label for="sort-by" class="sr-only">Sort by</label>
      <select
        id="sort-by"
        name="value"
        class="rounded-l-lg border-zinc-300 py-2 text-sm focus:border-zinc-400 focus:ring-0"
      >
        <option :for={option <- @options} value={option} selected={option == @sort_by}>
          {option}
        </option>
      </select>
      <button
        type="button"
        phx-click={@on_toggle}
        aria-label={"Sort direction: #{@direction}"}
        class="rounded-r-lg border border-l-0 border-zinc-300 bg-white px-2 py-2 hover:bg-zinc-50"
      >
        <.icon
          name={if @direction == :desc, do: "hero-arrow-down", else: "hero-arrow-up"}
          class="h-5 w-5"
        />
      </button>
    </form>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :selected, :list, required: true
  attr :on_toggle, :string, required: true, doc: "event pushed with `value` = the clicked option"
  attr :on_clear, :string, required: true

  def multi_select(assigns) do
    ~H"""
    <div class="flex items-center">
      <details id={@id} class="relative">
        <summary class="flex cursor-pointer list-none items-center gap-2 rounded-l-lg border border-zinc-300 bg-white px-3 py-2 text-sm hover:bg-zinc-50">
          {@label}
          <span :if={@selected != []} class="rounded-full bg-zinc-900 px-2 text-xs text-white">
            {length(@selected)}
          </span>
        </summary>
        <ul class="absolute z-20 mt-1 max-h-60 w-56 overflow-y-auto rounded-lg border border-zinc-200 bg-white py-1 shadow-lg">
          <li :if={@options == []} class="px-3 py-2 text-sm text-zinc-500">Nothing to choose from</li>
          <li :for={option <- @options}>
            <button
              type="button"
              phx-click={@on_toggle}
              value={option}
              class="flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-zinc-50"
            >
              {option}
              <.icon :if={option in @selected} name="hero-check" class="h-4 w-4 text-emerald-600" />
            </button>
          </li>
        </ul>
      </details>
      <button
        type="button"
        phx-click={@on_clear}
        aria-label={"Clear #{@label}"}
        class="rounded-r-lg border border-l-0 border-zinc-300 bg-white px-2 py-2 hover:bg-zinc-50"
      >
        <.icon name="hero-x-mark" class="h-5 w-5" />
      </button>
    </div>
    """
  end

  attr :start_date, :string, default: nil
  attr :end_date, :string, default: nil

  attr :on_change, :string,
    required: true,
    doc: "receives %{\"start_date\" => _, \"end_date\" => _}"

  def date_range_filter(assigns) do
    ~H"""
    <form id={"#{@on_change}-form"} phx-change={@on_change} class="flex items-center gap-2 text-sm">
      <label class="flex items-center gap-1">
        <span class="text-zinc-600">From</span>
        <input
          type="date"
          name="start_date"
          value={@start_date}
          class="rounded-lg border-zinc-300 py-1.5 text-sm"
        />
      </label>
      <label class="flex items-center gap-1">
        <span class="text-zinc-600">To</span>
        <input
          type="date"
          name="end_date"
          value={@end_date}
          class="rounded-lg border-zinc-300 py-1.5 text-sm"
        />
      </label>
    </form>
    """
  end

  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :on_change, :string, required: true

  def pagination(assigns) do
    ~H"""
    <nav aria-label="Pagination" class="mt-4 flex items-center justify-center gap-1">
      <button
        type="button"
        phx-click={@on_change}
        value={@current_page - 1}
        disabled={@current_page <= 1}
        aria-label="Previous page"
        class="rounded-md px-2 py-1 hover:bg-zinc-100 disabled:opacity-40"
      >
        <.icon name="hero-chevron-left" class="h-4 w-4" />
      </button>
      <button
        :for={page <- 1..@total_pages//1}
        type="button"
        phx-click={@on_change}
        value={page}
        aria-current={if page == @current_page, do: "page"}
        class={[
          "min-w-8 rounded-md px-2 py-1 text-sm",
          if(page == @current_page, do: "bg-zinc-900 text-white", else: "hover:bg-zinc-100")
        ]}
      >
        {page}
      </button>
      <button
        type="button"
        phx-click={@on_change}
        value={@current_page + 1}
        disabled={@current_page >= @total_pages}
        aria-label="Next page"
        class="rounded-md px-2 py-1 hover:bg-zinc-100 disabled:opacity-40"
      >
        <.icon name="hero-chevron-right" class="h-4 w-4" />
      </button>
    </nav>
    """
  end

  attr :page_size, :integer, required: true
  attr :on_change, :string, required: true
  attr :options, :list, default: [5, 10]

  def page_size_select(assigns) do
    ~H"""
    <form id={"#{@on_change}-form"} phx-change={@on_change} class="flex items-center gap-2 text-sm">
      <label for="page-size" class="text-zinc-600">Per page</label>
      <select id="page-size" name="value" class="rounded-lg border-zinc-300 py-1.5 text-sm">
        <option :for={size <- @options} value={size} selected={size == @page_size}>
          {size}
        </option>
      </select>
    </form>
    """
  end

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :sort, :map, default: %{column: nil, direction: :asc}
  attr :on_sort, :string, default: nil, doc: "event pushed with `value` = the column name"
  attr :row_id, :any, default: nil, doc: "function deriving a DOM id from a row"
  attr :empty_text, :string, default: "Nothing found"

  slot :col, required: true do
    attr :label, :string
    attr :sort_by, :atom, doc: "makes the header clickable and sorts by this key"
  end

  slot :action

  def data_table(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded-lg border border-zinc-200 bg-white">
      <table id={@id} class="w-full text-left text-sm">
        <thead class="border-b border-zinc-200 bg-zinc-50 text-zinc-500">
          <tr>
            <th :for={col <- @col} scope="col" class="px-4 py-2.5 font-medium">
              <%= if col[:sort_by] && @on_sort do %>
                <button
                  type="button"
                  phx-click={@on_sort}
                  value={col.sort_by}
                  class="inline-flex items-center gap-1 hover:text-zinc-900"
                >
                  {col.label}
                  <.icon
                    :if={@sort.column == col.sort_by}
                    name={
                      if @sort.direction == :asc, do: "hero-chevron-up", else: "hero-chevron-down"
                    }
                    class="h-3 w-3"
                  />
                </button>
              <% else %>
                {col[:label]}
              <% end %>
            </th>
            <th :if={@action != []} scope="col" class="px-4 py-2.5">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-zinc-100">
          <tr :if={@rows == []}>
            <td colspan={length(@col) + 1} class="px-4 py-6 text-center text-zinc-500">
              {@empty_text}
            </td>
          </tr>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="hover:bg-zinc-50">
            <td :for={col <- @col} class="px-4 py-2.5 text-zinc-800">{render_slot(col, row)}</td>
            <td :if={@action != []} class="px-4 py-2.5">
              <div class="flex justify-end gap-1">{render_slot(@action, row)}</div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :rest, :global, include: ~w(value disabled)

  def icon_button(assigns) do
    ~H"""
    <button
      type="button"
      aria-label={@label}
      title={@label}
      class="rounded-md p-1.5 text-zinc-600 hover:bg-zinc-100 hover:text-zinc-900 disabled:opacity-40"
      {@rest}
    >
      <.icon name={@icon} class="h-5 w-5" />
    </button>
    """
  end

  @doc "Human-readable text for LiveView upload errors (all uploads accept one image up to 10 MB)."
  def upload_error_message(:too_large), do: "The file is larger than 10 MB"
  def upload_error_message(:not_accepted), do: "Only .jpg, .jpeg and .png files are accepted"
  def upload_error_message(:too_many_files), do: "Only one file at a time"
  def upload_error_message(_other), do: "The file can't be uploaded"

  @doc "Formats a timestamp the way all admin tables show it."
  def format_datetime(nil), do: "—"
  def format_datetime(datetime), do: Calendar.strftime(datetime, "%b %d, %Y, %H:%M UTC")
end
