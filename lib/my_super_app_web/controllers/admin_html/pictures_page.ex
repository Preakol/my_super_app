defmodule MySuperAppWeb.PicturesPage do
  @moduledoc "Admin gallery: upload pictures to Cloudinary and (re)assign them to posts."
  use MySuperAppWeb, :admin_live_view

  import MySuperAppWeb.ImageHelpers

  alias MySuperApp.{Accounts, AdminPubSub, Blog, Blog.Picture}

  @sorting_options ["Upload At", "File Name"]
  @default_filters %{search: "", tags: [], extension: "", sorting: {:desc, "Upload At"}}
  @upload_opts [accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 10_000_000]

  def mount(_params, session, socket) do
    if connected?(socket), do: AdminPubSub.subscribe("blog")

    {:ok,
     socket
     |> assign(
       page_title: "Pictures",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       filters: @default_filters,
       sorting_options: @sorting_options,
       add_form: nil,
       selected: nil,
       picture_to_delete: nil
     )
     |> load_pictures()
     |> allow_upload(:new_picture, @upload_opts)
     |> allow_upload(:replacement, @upload_opts)}
  end

  @doc "Super admins may delete any picture; others only unassigned ones or those on their own posts."
  def can_delete?(current_user, %Picture{post: post}) do
    current_user.permissions == 1 or is_nil(post) or post.user_id == current_user.id
  end

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}
  def handle_info(:blog_updated, socket), do: {:noreply, load_pictures(socket)}
  def handle_info(:publish_update, socket), do: {:noreply, socket}

  def handle_event("change_search", %{"search" => search}, socket),
    do: {:noreply, update_filters(socket, %{socket.assigns.filters | search: search})}

  def handle_event("change_extension", %{"extension" => extension}, socket),
    do: {:noreply, update_filters(socket, %{socket.assigns.filters | extension: extension})}

  def handle_event("toggle_tag_filter", %{"value" => tag}, socket) do
    tags = socket.assigns.filters.tags
    tags = if tag in tags, do: List.delete(tags, tag), else: [tag | tags]
    {:noreply, update_filters(socket, %{socket.assigns.filters | tags: tags})}
  end

  def handle_event("clear_tag_filter", _params, socket),
    do: {:noreply, update_filters(socket, %{socket.assigns.filters | tags: []})}

  def handle_event("change_sort", %{"value" => option}, socket) when option in @sorting_options do
    {direction, _} = socket.assigns.filters.sorting
    {:noreply, update_filters(socket, %{socket.assigns.filters | sorting: {direction, option}})}
  end

  def handle_event("toggle_sort_direction", _params, socket) do
    {direction, option} = socket.assigns.filters.sorting
    flipped = if direction == :desc, do: :asc, else: :desc
    {:noreply, update_filters(socket, %{socket.assigns.filters | sorting: {flipped, option}})}
  end

  def handle_event("clear_filters", _params, socket),
    do: {:noreply, update_filters(socket, @default_filters)}

  def handle_event("open_add", _params, socket) do
    {:noreply, assign(socket, add_form: to_form(%{"post_id" => ""}, as: :picture))}
  end

  def handle_event("validate_add", %{"picture" => params}, socket) do
    {:noreply, assign(socket, add_form: to_form(params, as: :picture))}
  end

  def handle_event("add", %{"picture" => %{"post_id" => post_id}}, socket) do
    case store_upload(socket, :new_picture, post_id) do
      {:ok, attrs} ->
        case Blog.create_picture(attrs) do
          {:ok, _picture} -> {:noreply, done(socket, :info, "Picture added")}
          {:error, _changeset} -> {:noreply, done(socket, :error, "Picture could not be saved")}
        end

      {:error, message} ->
        {:noreply, done(socket, :error, message)}
    end
  end

  def handle_event("open_picture", %{"value" => id}, socket) do
    case Blog.get_picture(id) do
      %Picture{} = picture ->
        {:noreply,
         assign(socket,
           selected: %{picture: picture, form: to_form(%{"post_id" => ""}, as: :picture)}
         )}

      nil ->
        {:noreply, put_flash(socket, :error, "Picture not found")}
    end
  end

  def handle_event("validate_selected", %{"picture" => params}, socket) do
    {:noreply, update(socket, :selected, &%{&1 | form: to_form(params, as: :picture)})}
  end

  def handle_event("validate_selected", _params, socket), do: {:noreply, socket}

  def handle_event("assign", %{"picture" => %{"post_id" => post_id}}, socket)
      when post_id != "" do
    case Blog.update_picture(socket.assigns.selected.picture, %{"post_id" => post_id},
           skip_date_update: true
         ) do
      {:ok, _picture} -> {:noreply, done(socket, :info, "Picture assigned")}
      {:error, _changeset} -> {:noreply, done(socket, :error, "Picture could not be assigned")}
    end
  end

  def handle_event("assign", _params, socket),
    do: {:noreply, put_flash(socket, :error, "Select a post first")}

  def handle_event("unassign", _params, socket) do
    case Blog.update_picture(socket.assigns.selected.picture, %{"post_id" => nil},
           skip_date_update: true
         ) do
      {:ok, _picture} -> {:noreply, done(socket, :info, "Picture unassigned")}
      {:error, _changeset} -> {:noreply, done(socket, :error, "Picture could not be unassigned")}
    end
  end

  def handle_event("replace", _params, socket) do
    picture = socket.assigns.selected.picture

    with {:ok, attrs} <- store_upload(socket, :replacement, picture.post_id),
         {:ok, _updated} <- Blog.update_picture(picture, attrs) do
      delete_picture_from_cloud(picture)
      {:noreply, done(socket, :info, "Picture updated")}
    else
      {:error, %Ecto.Changeset{}} ->
        {:noreply, done(socket, :error, "Picture could not be saved")}

      {:error, message} ->
        {:noreply, done(socket, :error, message)}
    end
  end

  def handle_event("ask_delete", _params, socket) do
    picture = socket.assigns.selected.picture

    if can_delete?(socket.assigns.current_user, picture),
      do: {:noreply, assign(socket, selected: nil, picture_to_delete: picture)},
      else:
        {:noreply, put_flash(socket, :error, "You can only delete pictures of your own posts")}
  end

  def handle_event(
        "delete",
        _params,
        %{assigns: %{picture_to_delete: %Picture{} = picture}} = socket
      ) do
    case Blog.delete_picture(picture) do
      {:ok, deleted} ->
        delete_picture_from_cloud(deleted)
        {:noreply, done(socket, :info, "Picture deleted")}

      {:error, _changeset} ->
        {:noreply, done(socket, :error, "Picture could not be deleted")}
    end
  end

  def handle_event("delete", _params, socket),
    do: {:noreply, assign(socket, picture_to_delete: nil)}

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> cancel_all_uploads(:new_picture)
     |> cancel_all_uploads(:replacement)
     |> assign(add_form: nil, selected: nil, picture_to_delete: nil)}
  end

  defp store_upload(socket, upload, post_id) do
    results =
      consume_uploaded_entries(socket, upload, fn meta, entry ->
        {:ok,
         entry.client_name |> get_filename_and_format() |> upload_picture_to_cloud(meta.path)}
      end)

    case results do
      [{:ok, uploaded}] -> {:ok, get_picture_attrs(uploaded, post_id)}
      [{:error, _reason}] -> {:error, "Image storage is unavailable, picture was not uploaded"}
      [] -> {:error, "Choose an image first"}
    end
  end

  defp cancel_all_uploads(socket, upload) do
    Enum.reduce(
      socket.assigns.uploads[upload].entries,
      socket,
      &cancel_upload(&2, upload, &1.ref)
    )
  end

  defp done(socket, kind, message) do
    Process.send_after(self(), :clear_flash, 3000)

    socket
    |> put_flash(kind, message)
    |> assign(add_form: nil, selected: nil, picture_to_delete: nil)
    |> load_pictures()
  end

  defp update_filters(socket, filters), do: socket |> assign(filters: filters) |> load_pictures()

  defp load_pictures(socket) do
    %{sorting: sorting} = filters = socket.assigns.filters

    assign(socket,
      pictures: Blog.list_pictures_by_filters(%{filters | sorting: [sorting]}),
      tag_options: Blog.tags_with_pictures(),
      extensions: Blog.list_picture_extensions(),
      post_options: post_options(socket.assigns.current_user)
    )
  end

  defp post_options(user) do
    Enum.map(Blog.get_post_titles_by_user(user), fn post ->
      label = if post.picture, do: "#{post.key} (#{post.picture})", else: post.key
      [key: label, value: post.value, disabled: post.disabled]
    end)
  end

  attr :upload, :any, required: true
  attr :label, :string, required: true

  defp upload_field(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <label class="text-sm font-semibold text-zinc-800" for={@upload.ref}><%= @label %></label>
      <.live_file_input upload={@upload} class="text-sm" />
      <div :for={entry <- @upload.entries} class="flex flex-col gap-2">
        <.live_img_preview entry={entry} class="max-h-48 w-auto self-start rounded-lg" />
        <progress value={entry.progress} max="100" class="w-full"><%= entry.progress %>%</progress>
        <p :for={err <- upload_errors(@upload, entry)} class="text-sm text-red-600">
          <%= upload_error_message(err) %>
        </p>
      </div>
      <p :for={err <- upload_errors(@upload)} class="text-sm text-red-600">
        <%= upload_error_message(err) %>
      </p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <.page_title title="Pictures">
      <:actions>
        <.secondary_button phx-click="clear_filters">Clear filters</.secondary_button>
        <.button phx-click="open_add">Add new picture</.button>
      </:actions>
    </.page_title>

    <div class="mb-6 flex flex-wrap items-center gap-3">
      <form id="change-search-form" phx-change="change_search" phx-submit="change_search" class="w-full max-w-md">
        <label for="picture-search" class="sr-only">Search</label>
        <input
          id="picture-search"
          type="search"
          name="search"
          value={@filters.search}
          placeholder="Search by post id or title, file name, author name or email"
          phx-debounce="200"
          class="w-full rounded-lg border-zinc-300 text-sm"
        />
      </form>
      <.sort_control
        options={@sorting_options}
        sort_by={elem(@filters.sorting, 1)}
        direction={elem(@filters.sorting, 0)}
        on_change="change_sort"
        on_toggle="toggle_sort_direction"
      />
      <.multi_select
        id="picture-tag-filter"
        label="Tags"
        options={@tag_options}
        selected={@filters.tags}
        on_toggle="toggle_tag_filter"
        on_clear="clear_tag_filter"
      />
      <form id="change-extension-form" phx-change="change_extension">
        <label for="extension-filter" class="sr-only">Extension</label>
        <select id="extension-filter" name="extension" class="rounded-lg border-zinc-300 text-sm">
          <option value="">All extensions</option>
          <option
            :for={ext <- @extensions}
            value={ext.value}
            selected={ext.value == @filters.extension}
          >
            <%= ext.key %>
          </option>
        </select>
      </form>
    </div>

    <p :if={@pictures == []} class="py-10 text-center text-zinc-500">
      No pictures match these filters.
    </p>

    <ul id="pictures" class="grid grid-cols-2 gap-4 sm:grid-cols-3 xl:grid-cols-5">
      <li :for={picture <- @pictures} id={"picture-#{picture.id}"}>
        <button
          type="button"
          phx-click="open_picture"
          value={picture.id}
          class="flex h-full w-full flex-col overflow-hidden rounded-lg border border-zinc-200 bg-white text-left hover:border-zinc-400"
        >
          <div class="flex h-40 items-center justify-center bg-zinc-100">
            <img
              src={picture.path}
              alt={picture.file_name}
              loading="lazy"
              class="max-h-full max-w-full object-contain"
            />
          </div>
          <div class="flex flex-col gap-0.5 p-3 text-xs text-zinc-600">
            <span class="truncate font-medium text-zinc-900"><%= picture.file_name %></span>
            <%= if picture.post do %>
              <span class="truncate">Post #<%= picture.post.id %>: <%= picture.post.title %></span>
              <span class="truncate">
                <%= picture.post.user.login %> · <%= picture.post.user.email %>
              </span>
            <% else %>
              <span>Not assigned</span>
            <% end %>
            <span><%= format_datetime(picture.upload_at) %></span>
          </div>
        </button>
      </li>
    </ul>

    <.modal :if={@add_form} id="add-picture-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-2 text-lg font-semibold text-zinc-900">Add picture</h2>
      <.simple_form for={@add_form} id="add-picture-form" phx-change="validate_add" phx-submit="add">
        <.input
          field={@add_form[:post_id]}
          type="select"
          label="Post"
          prompt="Without post"
          options={@post_options}
        />
        <.upload_field upload={@uploads.new_picture} label="Image" />
        <:actions>
          <div class="flex w-full justify-end gap-2">
            <.secondary_button phx-click="close_modal">Cancel</.secondary_button>
            <.button disabled={@uploads.new_picture.entries == []}>Upload picture</.button>
          </div>
        </:actions>
      </.simple_form>
    </.modal>

    <.modal :if={@selected} id="picture-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-4 text-lg font-semibold text-zinc-900">
        <%= if @selected.picture.post,
          do: ~s(Picture for "#{@selected.picture.post.title}"),
          else: "Assign picture to a post" %>
      </h2>
      <img
        :if={@uploads.replacement.entries == []}
        src={@selected.picture.path}
        alt={@selected.picture.file_name}
        class="mb-4 max-h-64 rounded-lg"
      />
      <%= if @selected.picture.post do %>
        <form
          id="replace-picture-form"
          phx-change="validate_selected"
          phx-submit="replace"
          class="flex flex-col gap-4"
        >
          <.upload_field upload={@uploads.replacement} label="Replace image" />
          <div class="flex flex-wrap justify-end gap-2">
            <.secondary_button
              phx-click="ask_delete"
              disabled={!can_delete?(@current_user, @selected.picture)}
              class="text-red-700"
            >
              Delete
            </.secondary_button>
            <.secondary_button phx-click="unassign">Unassign</.secondary_button>
            <.button disabled={@uploads.replacement.entries == []}>Update</.button>
          </div>
        </form>
      <% else %>
        <.simple_form
          for={@selected.form}
          id="assign-picture-form"
          phx-change="validate_selected"
          phx-submit="assign"
        >
          <.input
            field={@selected.form[:post_id]}
            type="select"
            label="Post"
            prompt="Please select a post"
            options={@post_options}
          />
          <:actions>
            <div class="flex w-full justify-end gap-2">
              <.secondary_button phx-click="ask_delete" class="text-red-700">
                Delete
              </.secondary_button>
              <.button disabled={@selected.form.params["post_id"] in [nil, ""]}>
                Assign picture
              </.button>
            </div>
          </:actions>
        </.simple_form>
      <% end %>
    </.modal>

    <.confirm_modal
      :if={@picture_to_delete}
      id="delete-picture-modal"
      title={"Delete picture #{@picture_to_delete.file_name}?"}
      on_cancel="close_modal"
      on_confirm="delete"
    />
    """
  end
end
