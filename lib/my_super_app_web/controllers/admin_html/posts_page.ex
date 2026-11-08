defmodule MySuperAppWeb.PostsPage do
  @moduledoc "Admin blog: filter, create, edit, publish and delete posts."
  use MySuperAppWeb, :admin_live_view

  alias MySuperApp.{Accounts, AdminPubSub, Blog, Blog.Post}
  alias MySuperApp.Jobs.Email

  @sorting_options ["Updated At", "Published At", "Title", "Author", "Post Content Length"]
  @default_filters %{search: "", author: "All Authors", tags: [], sorting: {:desc, "Updated At"}}
  @publish_lock_minutes 5

  def mount(_params, session, socket) do
    if connected?(socket), do: AdminPubSub.subscribe("blog")

    {:ok,
     socket
     |> assign(
       page_title: "Posts",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       filters: @default_filters,
       sorting_options: @sorting_options,
       open_posts: MapSet.new(),
       form: nil,
       form_action: nil,
       new_tag: "",
       post_to_delete: nil
     )
     |> load_posts()}
  end

  @doc "A post can't be (un)published again until a few minutes after its last change."
  def publish_locked?(%Post{updated_at: updated_at}, now \\ DateTime.utc_now()),
    do: DateTime.diff(now, updated_at, :minute) < @publish_lock_minutes

  @doc "Only the author or a super admin may change a post."
  def can_edit?(current_user, post),
    do: post.user_id == current_user.id or current_user.permissions == 1

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}
  def handle_info(:blog_updated, socket), do: {:noreply, load_posts(socket)}
  def handle_info(:publish_update, socket), do: {:noreply, load_posts(socket)}

  def handle_event("change_search", %{"search" => search}, socket),
    do: {:noreply, update_filters(socket, %{socket.assigns.filters | search: search})}

  def handle_event("change_author", %{"author" => author}, socket),
    do: {:noreply, update_filters(socket, %{socket.assigns.filters | author: author})}

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

  def handle_event("toggle_post", %{"value" => id}, socket) do
    open = socket.assigns.open_posts
    open = if MapSet.member?(open, id), do: MapSet.delete(open, id), else: MapSet.put(open, id)
    {:noreply, assign(socket, open_posts: open)}
  end

  def handle_event("toggle_published", %{"value" => id}, socket) do
    with %Post{} = post <- Blog.get_post(id),
         true <- can_edit?(socket.assigns.current_user, post),
         false <- publish_locked?(post) do
      published_at = if post.published_at, do: nil, else: DateTime.utc_now()

      post
      |> Blog.update_published_at(%{"user_id" => post.user_id, "published_at" => published_at})
      |> Email.get_post_publishing_args()
      |> Email.new()
      |> Oban.insert()

      {:noreply, socket}
    else
      _ -> {:noreply, put_flash(socket, :error, "This post can't be (un)published right now")}
    end
  end

  def handle_event("open_create", _params, socket) do
    {:noreply,
     assign(socket,
       form: %Post{} |> Blog.change_post(%{"tags" => []}) |> to_form(),
       form_action: :create,
       new_tag: ""
     )}
  end

  def handle_event("open_edit", %{"value" => id}, socket) do
    case Blog.get_post(id) do
      %Post{} = post ->
        tags = Enum.map(post.tags, &%{"title" => &1.title, "color" => &1.color})

        {:noreply,
         assign(socket,
           form: post |> Blog.change_post(%{"tags" => tags}) |> to_form(),
           form_action: :update,
           new_tag: ""
         )}

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  def handle_event("validate", %{"post" => attrs}, socket) do
    {:noreply,
     assign(socket,
       new_tag: Map.get(attrs, "tag", ""),
       form:
         rebuild_form(socket.assigns.form, Map.put(attrs, "tags", form_tags(socket.assigns.form)))
     )}
  end

  def handle_event("add_tag", _params, %{assigns: %{new_tag: title}} = socket) do
    case String.trim(title) do
      "" ->
        {:noreply, socket}

      title ->
        tags =
          (form_tags(socket.assigns.form) ++ [%{"title" => title, "color" => "bg-popo"}])
          |> Enum.uniq_by(&String.upcase(&1["title"]))

        params = socket.assigns.form.params |> Map.put("tags", tags) |> Map.put("tag", "")
        {:noreply, assign(socket, new_tag: "", form: rebuild_form(socket.assigns.form, params))}
    end
  end

  def handle_event("remove_tag", %{"value" => title}, socket) do
    tags = Enum.reject(form_tags(socket.assigns.form), &(&1["title"] == title))

    {:noreply,
     assign(socket,
       form: rebuild_form(socket.assigns.form, Map.put(socket.assigns.form.params, "tags", tags))
     )}
  end

  def handle_event("save", %{"post" => attrs}, socket) do
    %{form: form, form_action: action, current_user: user} = socket.assigns
    params = Map.merge(attrs, %{"tags" => form_tags(form)})

    result =
      case action do
        :create -> Blog.create_post(Map.put(params, "user_id", user.id))
        :update -> Blog.update_post(form.data, Map.put(params, "user_id", form.data.user.id))
      end

    case result do
      {:ok, _post} ->
        Process.send_after(self(), :clear_flash, 3000)

        filters =
          if action == :create,
            do: %{@default_filters | author: user.login},
            else: %{socket.assigns.filters | tags: [], sorting: @default_filters.sorting}

        {:noreply,
         socket
         |> put_flash(:info, if(action == :create, do: "Post created", else: "Post updated"))
         |> assign(form: nil, form_action: nil, open_posts: MapSet.new())
         |> update_filters(filters)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("open_delete", %{"value" => id}, socket),
    do: {:noreply, assign(socket, post_to_delete: Blog.get_post(id))}

  def handle_event("close_modal", _params, socket),
    do: {:noreply, assign(socket, form: nil, form_action: nil, post_to_delete: nil)}

  def handle_event("delete", _params, %{assigns: %{post_to_delete: %Post{} = post}} = socket) do
    Process.send_after(self(), :clear_flash, 3000)

    socket =
      case Blog.delete_post(post) do
        {:ok, _post} -> put_flash(socket, :info, "Post deleted")
        {:error, _changeset} -> put_flash(socket, :error, "Post could not be deleted")
      end

    {:noreply, socket |> assign(post_to_delete: nil) |> load_posts()}
  end

  def handle_event("delete", _params, socket), do: {:noreply, assign(socket, post_to_delete: nil)}

  defp form_tags(form), do: form.params["tags"] || []

  defp rebuild_form(form, params) do
    form.data
    |> Blog.change_post(params)
    |> to_form(action: :validate)
  end

  defp update_filters(socket, filters), do: socket |> assign(filters: filters) |> load_posts()

  defp load_posts(socket) do
    %{sorting: sorting} = filters = socket.assigns.filters

    assign(socket,
      posts: Blog.list_posts_by_filters(%{filters | sorting: [sorting]}),
      authors: ["All Authors" | Blog.get_authors()],
      tag_options: Blog.tags_with_posts()
    )
  end

  defp columns(posts),
    do: [Enum.take_every(posts, 2), posts |> Enum.drop(1) |> Enum.take_every(2)]

  def render(assigns) do
    ~H"""
    <.page_title title="Posts">
      <:actions>
        <.secondary_button phx-click="clear_filters">Clear filters</.secondary_button>
        <.button phx-click="open_create">Add new post</.button>
      </:actions>
    </.page_title>

    <div class="mb-6 flex flex-wrap items-center gap-3">
      <form
        id="change-search-form"
        phx-change="change_search"
        phx-submit="change_search"
        class="w-full max-w-xs"
      >
        <label for="post-search" class="sr-only">Search by post title</label>
        <input
          id="post-search"
          type="search"
          name="search"
          value={@filters.search}
          placeholder="Search by post title"
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
      <form id="change-author-form" phx-change="change_author">
        <label for="author-filter" class="sr-only">Author</label>
        <select id="author-filter" name="author" class="rounded-lg border-zinc-300 text-sm">
          <option :for={author <- @authors} value={author} selected={author == @filters.author}>
            {author}
          </option>
        </select>
      </form>
      <.multi_select
        id="tag-filter"
        label="Tags"
        options={@tag_options}
        selected={@filters.tags}
        on_toggle="toggle_tag_filter"
        on_clear="clear_tag_filter"
      />
    </div>

    <p :if={@posts == []} class="py-10 text-center text-zinc-500">No posts match these filters.</p>

    <div class="grid gap-6 lg:grid-cols-2">
      <div :for={column <- columns(@posts)} class="flex flex-col gap-6">
        <article
          :for={post <- column}
          id={"post-#{post.id}"}
          class="rounded-lg border border-zinc-200 bg-white"
        >
          <button
            type="button"
            phx-click="toggle_post"
            value={post.id}
            aria-expanded={to_string(MapSet.member?(@open_posts, to_string(post.id)))}
            class="flex w-full flex-col gap-3 p-4 text-left"
          >
            <div class="flex w-full items-start justify-between gap-4">
              <h2 class="text-lg font-semibold text-zinc-900">{post.title}</h2>
              <div class="shrink-0 text-right text-xs text-zinc-500">
                <div>{post.user.login}</div>
                <div>Updated {format_datetime(post.updated_at)}</div>
                <div class={if post.published_at, do: "text-emerald-700", else: "text-zinc-500"}>
                  {if post.published_at,
                    do: "Published #{format_datetime(post.published_at)}",
                    else: "Not published"}
                </div>
              </div>
            </div>
            <div :if={post.tags != []} class="flex flex-wrap gap-2">
              <.tag_badge :for={tag <- post.tags} tag={tag} />
            </div>
          </button>
          <div
            :if={MapSet.member?(@open_posts, to_string(post.id))}
            class="border-t border-zinc-100 p-4"
          >
            <div class="flex flex-col gap-4 sm:flex-row">
              <img
                :if={post.picture}
                id={"post-#{post.id}-picture"}
                src={post.picture.path}
                alt={"Picture for #{post.title}"}
                class="h-52 w-52 shrink-0 rounded-lg object-cover"
              />
              <p class="whitespace-pre-line text-sm text-zinc-700">{post.body}</p>
            </div>
            <div :if={can_edit?(@current_user, post)} class="mt-4 flex flex-wrap justify-end gap-2">
              <.publish_toggle
                published={!is_nil(post.published_at)}
                disabled={publish_locked?(post)}
                phx-click="toggle_published"
                value={post.id}
              />
              <.secondary_button phx-click="open_edit" value={post.id}>Edit</.secondary_button>
              <.secondary_button phx-click="open_delete" value={post.id} class="text-red-700">
                Delete
              </.secondary_button>
            </div>
          </div>
        </article>
      </div>
    </div>

    <.modal :if={@form} id="post-modal" show on_cancel={JS.push("close_modal")}>
      <h2 class="mb-2 text-lg font-semibold text-zinc-900">
        {if @form_action == :create, do: "Create new post", else: "Edit post"}
      </h2>
      <.simple_form for={@form} id="post-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} label="Title" placeholder="Post title" />
        <.input field={@form[:body]} type="textarea" label="Content" placeholder="Write your content" />
        <div>
          <span class="block text-sm font-semibold text-zinc-800">Tags</span>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <.tag_badge :for={tag <- @form.params["tags"] || []} tag={tag}>
              <button
                type="button"
                phx-click="remove_tag"
                value={tag["title"]}
                aria-label={"Remove tag #{tag["title"]}"}
              >
                <.icon name="hero-x-mark" class="h-3 w-3" />
              </button>
            </.tag_badge>
            <div class="flex items-center">
              <label for="new-tag" class="sr-only">New tag</label>
              <input
                id="new-tag"
                type="text"
                name="post[tag]"
                value={@new_tag}
                placeholder="Add new tag"
                class="rounded-l-lg border-zinc-300 py-1 text-sm"
              />
              <button
                type="button"
                phx-click="add_tag"
                aria-label="Add tag"
                class="rounded-r-lg border border-l-0 border-zinc-300 bg-white px-2 py-1 hover:bg-zinc-50"
              >
                <.icon name="hero-plus" class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
        <:actions>
          <div class="flex w-full justify-end gap-2">
            <.secondary_button phx-click="close_modal">Cancel</.secondary_button>
            <.button>{if @form_action == :create, do: "Create", else: "Update"}</.button>
          </div>
        </:actions>
      </.simple_form>
    </.modal>

    <.confirm_modal
      :if={@post_to_delete}
      id="delete-post-modal"
      title="Delete post?"
      on_cancel="close_modal"
      on_confirm="delete"
    />
    """
  end
end
