defmodule MySuperAppWeb.PictureController do
  @moduledoc false

  use MySuperAppWeb, :controller

  import MySuperAppWeb.ImageHelpers

  alias MySuperApp.{Blog, Blog.Picture, Blog.Post, Repo}
  alias MySuperAppWeb.SortParams

  action_fallback MySuperAppWeb.FallbackController

  def index(conn, params) do
    with {:ok, sorting} <-
           SortParams.parse(params, Blog.picture_sort_options(), Blog.default_picture_sorting()),
         {:ok, key, [_ | _] = pictures} <- fetch_pictures(params, sorting) do
      render(conn, :index, [{key, pictures}])
    else
      {:ok, _key, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{data: [], message: "No matching records found", status: "not_found"})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})

      {:error, _invalid_date} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Bad pattern for date and time, right pattern: yyyy-mm-ddThh:mm:ssZ"})
    end
  end

  defp fetch_pictures(%{"author_email" => email}, _sorting),
    do: {:ok, :pictures, Blog.get_pictures_by_author_email(email)}

  defp fetch_pictures(%{"author_name" => name}, _sorting),
    do: {:ok, :pictures, Blog.get_pictures_by_author_name(name)}

  defp fetch_pictures(%{"start_date" => start_date, "end_date" => end_date}, sorting),
    do: with_paths(Blog.get_pictures_by_period(start_date, end_date, sorting))

  defp fetch_pictures(%{"date" => date}, sorting),
    do: with_paths(Blog.get_pictures_by_date(date, sorting))

  defp fetch_pictures(_params, sorting), do: {:ok, :pictures, Blog.list_pictures(sorting)}

  defp with_paths({:error, reason}), do: {:error, reason}
  defp with_paths(pictures) when is_list(pictures), do: {:ok, :paths, pictures}

  def show_by_post(conn, %{"post_id" => post_id}) do
    case Blog.get_picture_by_post_id(post_id) do
      %Picture{} = picture ->
        render(conn, :show, picture: picture)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Post with post_id: #{post_id}, not found"})
    end
  end

  def show(conn, %{"id" => id}) do
    case Blog.get_picture(id) do
      %Picture{} = picture ->
        render(conn, :show, path: picture.path)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Post with id: #{id}, not found"})
    end
  end

  def create(conn, %{"file" => file, "post_id" => post_id}) do
    with {:post, %Post{}} <- {:post, Repo.get(Post, post_id)},
         {:existing, nil} <- {:existing, Repo.get_by(Picture, post_id: post_id)},
         {:ok, picture} <- upload_and_create_picture(file, post_id) do
      render_created(conn, picture)
    else
      {:post, nil} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no post with id #{post_id}."})

      {:existing, %Picture{}} ->
        conn
        |> put_status(409)
        |> json(%{error: "Picture for post with id #{post_id} already exists."})

      {:error, reason} ->
        upload_failed(conn, reason)
    end
  end

  def create(conn, %{"file" => file}) do
    case upload_and_create_picture(file, "") do
      {:ok, picture} -> render_created(conn, picture)
      {:error, reason} -> upload_failed(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    with %Picture{} = picture <- Blog.get_picture(id),
         {:ok, %Picture{}} <- Blog.delete_picture(picture) do
      delete_picture_from_cloud(picture)

      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no Picture with id #{id}."})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Occurred an error during deletion.", reason: reason})
    end
  end

  def update(conn, %{"file" => file, "id" => id}) do
    case Repo.get(Picture, id) do
      %Picture{} = picture ->
        with {:ok, uploaded} <-
               upload_picture_to_cloud(get_filename_and_format(file.filename), file.path),
             {:ok, updated_picture} <-
               Blog.update_picture(picture, get_picture_attrs(uploaded, picture.post_id)) do
          delete_picture_from_cloud(picture)

          conn
          |> put_status(:ok)
          |> render(:show, picture: updated_picture)
        else
          {:error, reason} -> upload_failed(conn, reason)
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no picture with id #{id}."})
    end
  end

  defp upload_and_create_picture(file, post_id) do
    with {:ok, uploaded} <-
           upload_picture_to_cloud(get_filename_and_format(file.filename), file.path) do
      uploaded
      |> get_picture_attrs(post_id)
      |> Blog.create_picture()
    end
  end

  defp render_created(conn, picture) do
    conn
    |> put_status(:created)
    |> put_resp_header("location", ~p"/api/posts/#{picture}")
    |> render(:show, picture: picture)
  end

  defp upload_failed(conn, %Ecto.Changeset{}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Picture could not be saved."})
  end

  defp upload_failed(conn, _reason) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "Image storage is unavailable, picture was not uploaded."})
  end
end
