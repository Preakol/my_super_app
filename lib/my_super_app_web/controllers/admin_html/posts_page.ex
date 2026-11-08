defmodule MySuperAppWeb.PostsPage do
  @moduledoc false
  use MySuperAppWeb, :admin_surface_live_view

  alias MySuperApp.{Blog, Accounts, Blog.Post, AdminPubSub}

  alias MySuperAppWeb.{MyDeleteModal, MySwitcher}
  alias Moon.Icons.{ArrowsUp, MailFilterCrossed, GenericCheckAlternative, GenericCheckRounded, GenericClose}
  alias Moon.Lego.Title
  alias Moon.Design.{
    Form,
    Form.Field,
    Form.Input,
    Form.TextArea,
    Modal,
    Button,
    Button.IconButton,
    Tag,
    Accordion,
    Dropdown,
    Chip
  }

  data(filters, :map, default: %{search: "", author: "All Authors", tags: [], sorting: [{:desc, "Updated At"}]})
  data(page_title, :string, default: "Posts")
  data(sorting_options, :list, default: ["Updated At", "Published At", "Title", "Author", "Post Content Length"])

  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminPubSub.subscribe("blog")
    end

    {:ok, assign(socket,
        current_user: Accounts.get_user_by_session_token(session["user_token"]),
        form: Blog.change_post(%Post{}, %{tags: []}) |> to_form(),
        form_action: :create,
        open_posts: [],
        modal_open: false,
        modal_delete_open: false,
        tag_dropdown_open: false,
        new_tag: "",
        post_to_delete: nil
      )
      |> update_content()
    }
  end

  defp update_content(socket) do
    assign(
      socket,
      posts: Blog.list_posts_by_filters(socket.assigns.filters),
      authors_to_choose: ["All Authors" | Blog.get_authors()],
      tags_to_choose: Blog.tags_with_posts()
    )
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:blog_updated, socket) do
    {:noreply, update_content(socket)}
  end

  def handle_info(:publish_update, socket) do
    {:noreply, assign(socket, posts: Blog.list_posts_by_filters(socket.assigns.filters))}
  end

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_published", %{"value" => value} = params, socket) do
    Blog.get_post(params["post"])
    |> Blog.update_published_at(%{"user_id" => params["user"], "published_at" => get_published_at(value)})
    |> MySuperApp.Jobs.Email.get_post_publishing_args()
    |> MySuperApp.Jobs.Email.new()
    |> Oban.insert()
    {:noreply, socket}
  end

  def handle_event("on_change_accordion", %{"value" => index}, socket) do
    {:noreply,
     assign(socket,
       open_posts:
         (Enum.member?(socket.assigns.open_posts, index) && Enum.filter(socket.assigns.open_posts, &(&1 != index)))
         || [index | socket.assigns.open_posts]
     )}
  end

  def handle_event("change_search", %{"value" => search}, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :search, search))}
  end

  def handle_event("change_author_filter", %{"value" => author}, socket) do
    Dropdown.close("authors_dropdown")
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :author, author))}
  end

  def handle_event("on_trigger_tag_filter", _, socket) do
    {:noreply, assign(socket, tag_dropdown_open: !socket.assigns.tag_dropdown_open)}
  end

  def handle_event("change_tag_filter", %{"value" => tag}, socket) do
    new_chosen_tags =
      (
        Enum.member?(socket.assigns.filters.tags, tag) &&
        Enum.filter(socket.assigns.filters.tags, &(&1 != tag))
      ) ||
      [tag | socket.assigns.filters.tags]

    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :tags, new_chosen_tags))}
  end

  def handle_event("clear_tag_filter", _, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :tags, []))}
  end

  def handle_event("change_sort_param", %{"value" => sort_param}, %{assigns: %{filters: %{sorting: [{dir, _sort_param}]}}} = socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :sorting, [{dir, sort_param}]))}
  end

  def handle_event("change_sort_dir", _, %{assigns: %{filters: %{sorting: [{dir, sort_param}]}}} = socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :sorting, [{dir == :desc && :asc || :desc, sort_param}]))}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply, update_filters(socket, %{search: "", author: "All Authors", tags: [], sorting: [{:desc, "Updated At"}]})}
  end

  def handle_event("modal_close", _, socket) do
    Modal.close("modal")
    Modal.close("modal_delete")
    {:noreply, assign(socket, modal_open: false, modal_delete_open: false)}
  end

  def handle_event("modal_open_create", _, socket) do
    Modal.open("modal")
    {
      :noreply,
      assign(
        socket,
        form:
          %Post{}
          |> Blog.change_post(%{tags: []})
          |> to_form(),
        form_action: "create",
        modal_open: true,
        new_tag: ""
      )
    }
  end

  def handle_event("modal_open_update", %{"value" => post_id}, socket) do
    Modal.open("modal")

    post = Blog.get_post(post_id)

    {:noreply,
      assign(socket,
        form:
          post
          |> Blog.change_post(%{tags: list_map_tags(post.tags || [])})
          |> to_form(),
        form_action: "update",
        modal_open: true,
        new_tag: ""
      )
    }
  end

  def handle_event("validate", %{"post" => attrs}, socket) do
    {:noreply,
      assign(socket,
        new_tag: attrs["tag"],
        form:
          socket.assigns.form.data
          |> Blog.change_post(attrs |> Map.put("tags", socket.assigns.form.params["tags"]))
          |> Map.put(:action, :insert)
          |> to_form()
      )
    }
  end

  def handle_event("add_tag", %{"value" => title}, socket) do
    updated_tags = socket.assigns.form.params["tags"] ++ [%{"title" => title, "color" => "bg-popo"}]
    {:noreply,
      assign(socket,
        form:
          socket.assigns.form.data
          |> Blog.change_post(
            socket.assigns.form.params
            |> Map.merge(%{"tags" => Enum.uniq_by(updated_tags, &(&1["title"] |> String.upcase)), "tag" => ""})
          )
          |> Map.put(:action, :insert)
          |> to_form()
      )
    }
  end

  def handle_event("remove_tag", %{"value" => title}, socket) do
    updated_tags = Enum.reject(socket.assigns.form.params["tags"], &(&1["title"] == title))
    {
      :noreply,
      assign(
        socket,
        form:
          socket.assigns.form.data
          |> Blog.change_post(Map.put(socket.assigns.form.params, "tags", updated_tags))
          |> Map.put(:action, :insert)
          |> to_form()
      )
    }
  end

  def handle_event("submit_form", _, socket) do
    socket.assigns.form_action
    |> submit_action(socket.assigns.form.data, socket.assigns)
    |> handle_submit_result(socket)
  end

  def handle_event("modal_delete_open", %{"value" => id}, socket) do
    {:noreply, assign(socket, modal_delete_open: true, post_to_delete: Blog.get_post(id))}
  end

  def handle_event("delete", _, socket) do
    Modal.close("modal_delete")
    Process.send_after(self(), :clear_flash, 3000)

    case Blog.delete_post(socket.assigns.post_to_delete) do
      {:ok, _post} ->
        {:noreply,
          assign(
            socket |> put_flash(:info, "Post deleted"),
            modal_delete_open: false
          )
        }

      {:error, _} ->
        {:noreply,
          assign(
            socket,
            modal_delete_open: false
          )
          |> update_content()
        }
    end
  end

  defp submit_action("create", _post_data, assigns) do
    Blog.create_post(Map.put(assigns.form.params, "user_id", assigns.current_user.id))
  end

  defp submit_action("update", post_data, assigns) do
    Blog.update_post(post_data, Map.put(assigns.form.params, "user_id", assigns.form.data.user.id))
  end

  defp handle_submit_result({:ok, _post}, %{assigns: %{form_action: form_action}} = socket) do
    Modal.close("modal")
    Process.send_after(self(), :clear_flash, 3000)

    {
      :noreply,
      assign(
        socket
        |> put_flash(:info, "Post #{socket.assigns.form_action}d"),
        modal_open: false,
        filters: get_new_filters(form_action, socket.assigns),
        open_posts: []
      )
    }
  end

  defp handle_submit_result({:error, %Ecto.Changeset{} = changeset}, socket) do
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  defp get_new_filters("create", assigns) do
    %{search: "", author: assigns.current_user.login, tags: [], sorting: [{:desc, "Updated At"}]}
  end

  defp get_new_filters("update", assigns) do
    Map.merge(assigns.filters, %{tags: [], sorting: [{:desc, "Updated At"}]})
  end

  defp get_published_at(""), do: DateTime.now!("Etc/UTC")
  defp get_published_at(_), do: nil

  defp update_filters(socket, new_filters) do
    assign(
      socket,
      filters: new_filters,
      posts: Blog.list_posts_by_filters(new_filters)
    )
  end

  defp list_map_tags(list) do
    list
    |> Enum.map(&(%{"title" => &1.title, "color" => &1.color}))
  end
end
