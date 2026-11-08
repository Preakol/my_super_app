defmodule MySuperAppWeb.PicturesPage do
  @moduledoc false
  use MySuperAppWeb, :admin_surface_live_view

  import MySuperAppWeb.ImageHelpers

  alias MySuperApp.{Blog, Accounts, Blog.Picture, AdminPubSub}

  alias MySuperAppWeb.{MyFormDropdown, MyDropdownOptions, MyDeleteModal}
  alias Moon.Icons.{
    ArrowsUp,
    MailFilterCrossed,
    GenericCheckAlternative
  }
  alias Moon.Design.{
    Form,
    Form.Field,
    Form.Input,
    Modal,
    Drawer,
    Button,
    Button.IconButton,
    Dropdown,
    Chip,
    Progress
  }

  data(page_title, :string, default: "Pictures")
  data(filters, :map, default: %{search: "", tags: [], extension: "", sorting: [{:desc, "Upload At"}]})
  data(sorting_options, :list, default: ["Upload At", "File Name"])

  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminPubSub.subscribe("blog")
    end

    {
      :ok,
      assign(socket,
        current_user: Accounts.get_user_by_session_token(session["user_token"]),
        tag_dropdown_open: false,
        modal_add_open: false,
        modal_delete_open: false,
        drawer_update_open: false,
        picture_to_delete: %Picture{},
        form_update: get_form(%Picture{}),
        form: get_form(%Picture{post_id: ""})
      )
      |> update_content()
      |> allow_upload(:new_picture, accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 10_000_000)
      |> allow_upload(:update_picture, accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 10_000_000)
    }
  end

  defp update_content(socket) do
    socket
    |> assign(
      pictures: Blog.list_pictures_by_filters(socket.assigns.filters),
      tags_to_choose: Blog.tags_with_pictures(),
      extension_options: [%{key: "All Extensions", value: ""} | Blog.list_picture_extensions()],
      posts_to_choose:
        [%{key: "Without post", value: "", picture: nil, disabled: false} | Blog.get_post_titles_by_user(socket.assigns.current_user)]
    )
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:blog_updated, socket) do
    {:noreply, update_content(socket)}
  end

  def handle_info(:publish_update, socket) do
    {:noreply, socket}
  end

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def handle_event("change_search", %{"value" => search}, socket) do
    {:noreply, update_filters(socket,  Map.put(socket.assigns.filters, :search, search))}
  end

  def handle_event("on_trigger_tag_filter", _, socket) do
    {:noreply, assign(socket, tag_dropdown_open: !socket.assigns.tag_dropdown_open)}
  end

  def handle_event("change_tag_filter", %{"value" => tag}, socket) do
    {:noreply,
      update_filters(socket,
        Map.put(socket.assigns.filters, :tags,
          if Enum.member?(socket.assigns.filters.tags, tag) do
            Enum.filter(socket.assigns.filters.tags, &(&1 != tag))
          else
            [tag | socket.assigns.filters.tags]
          end
        )
      )
    }
  end

  def handle_event("clear_tag_filter", _, socket) do
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :tags, []))}
  end

  def handle_event("change_sort_param", %{"value" => sort_param}, %{assigns: %{filters: %{sorting: [{dir, _sort_param}]}}} = socket) do
    {:noreply,
      update_filters(
        socket,
        socket.assigns.filters
        |> Map.put(:sorting, [{dir, sort_param}])
      )
    }
  end

  def handle_event("change_sort_dir", _, %{assigns: %{filters: %{sorting: [{dir, sort_param}]}}} = socket) do
    {:noreply,
      update_filters(
        socket,
        socket.assigns.filters
        |> Map.put(:sorting, [{dir == :desc && :asc || :desc, sort_param}])
      )
    }
  end

  def handle_event("change_extension_filter", %{"value" => ext}, socket) do
    Dropdown.close("extension_dropdown")
    {:noreply, update_filters(socket, Map.put(socket.assigns.filters, :extension, ext))}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply, update_filters(socket, %{search: "", tags: [], extension: "", sorting: [{:desc, "Upload At"}]})}
  end

  def handle_event("modal_delete_open", %{"value" => picture_id}, socket) do
    Modal.open("modal_delete")
    {:noreply, assign(socket, modal_delete_open: true, picture_to_delete: Blog.get_picture(picture_id))}
  end

  def handle_event("delete", _, socket) do
    Modal.close("modal_delete")
    Drawer.close("drawer_update")
    Process.send_after(self(), :clear_flash, 3000)

    case Blog.delete_picture(socket.assigns.picture_to_delete) do
      {:ok, picture} ->
        delete_picture_from_cloud(picture)

        {:noreply,
          socket
          |> put_flash(:info, "Picture deleted")
          |> assign(modal_delete_open: false, drawer_update_open: false)
        }

      {:error, _} ->
        {:noreply,
          socket
          |> assign(modal_delete_open: false, drawer_update_open: false)
          |> update_content()
        }
    end
  end

  def handle_event("validate", %{"picture" => attrs}, socket) do
    {:noreply, assign(socket, form: validate_form(%Picture{}, attrs))}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_update", %{"picture" => attrs}, socket) do
    {:noreply, assign(socket, form_update: validate_form(socket.assigns.form_update.data, attrs))}
  end

  def handle_event("validate_update", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("modal_add_open", _, socket) do
    Modal.open("modal_add")
    {:noreply, assign(socket, modal_add_open: true)}
  end

  def handle_event("add_picture", %{"picture" => %{"post_id" => post_id}}, socket) do
    Modal.close("modal_add")

    consume_uploaded_entries(socket, :new_picture, fn meta, entry ->
      get_filename_and_format(entry.client_name)
      |> upload_picture_to_cloud(meta.path)
    end)
    |> Enum.at(0)
    |> get_picture_attrs(post_id)
    |> Blog.create_picture()

    Process.send_after(self(), :clear_flash, 3000)
    {:noreply,
      socket
      |> put_flash(:info, "Picture added")
      |> assign(modal_add_open: false, form: get_form(%Picture{post_id: ""}))
    }
  end

  def handle_event("drawer_update_open", %{"value" => picture_id}, socket) do
    {:noreply,
      assign(socket,
        drawer_update_open: true,
        form_update:
          Blog.get_picture(picture_id)
          |> get_form()
      ) |> refresh_entries(:update_picture)
    }
  end

  def handle_event("unassign_picture", _, socket) do
    Drawer.close("drawer_update")

    socket.assigns.form_update.data
    |> Blog.update_picture(%{"post_id" => nil}, skip_date_update: true)

    Process.send_after(self(), :clear_flash, 3000)
    {
      :noreply,
        socket
        |> put_flash(:info, "Picture unassigned")
        |> assign(
          drawer_update_open: false
        )
    }
  end

  def handle_event("update_picture", %{"picture" => attrs}, socket) do
    Drawer.close("drawer_update")

    socket.assigns.form_update.data
    |> Blog.update_picture(attrs, skip_date_update: true)

    Process.send_after(self(), :clear_flash, 3000)
    {
      :noreply,
        socket
        |> put_flash(:info, "Picture updated")
        |> assign(
          drawer_update_open: false
        )
    }
  end

  def handle_event("update_picture", _, socket) do
    Drawer.close("drawer_update")

    attrs =
      consume_uploaded_entries(socket, :update_picture, fn meta, entry ->
        delete_picture_from_cloud(socket.assigns.form_update.data)

        get_filename_and_format(entry.client_name)
        |> upload_picture_to_cloud(meta.path)
      end)
      |> Enum.at(0)
      |> get_picture_attrs(socket.assigns.form_update.data.post_id)

    socket.assigns.form_update.data
    |> Blog.update_picture(attrs)

    Process.send_after(self(), :clear_flash, 3000)
    {
      :noreply,
        socket
        |> put_flash(:info, "Picture updated")
        |> assign(
          drawer_update_open: false
        )
    }
  end

  def handle_event("modal_add_close", _, socket) do
    Modal.close("modal_add")
    {:noreply, assign(socket, modal_add_open: false)}
  end

  def handle_event("drawer_update_close", _, socket) do
    Drawer.close("drawer_update")
    {:noreply, assign(socket, drawer_update_open: false)}
  end

  def handle_event("modal_delete_close", _, socket) do
    Modal.close("modal_delete")
    {:noreply, assign(socket, modal_delete_open: false)}
  end

  defp refresh_entries(socket, name) do
    case uploaded_entries(socket, name) do
      {_, [entry | _]} ->
        cancel_upload(socket, name, entry.ref)

      {_, _} ->
        socket
    end
  end

  defp validate_form(data, attrs) do
    Blog.change_picture(data, attrs)
    |> Map.put(:action, :insert)
    |> to_form()
  end

  defp get_form(data) do
    check_nil_post_id(data)
    |> Blog.change_picture()
    |> to_form()
  end

  defp check_nil_post_id(%Picture{post_id: nil} = picture), do: Map.put(picture, :post_id, "")
  defp check_nil_post_id(picture), do: picture

  defp update_filters(socket, new_filters) do
    assign(
      socket,
      filters: new_filters,
      pictures: Blog.list_pictures_by_filters(new_filters)
    )
  end
end
