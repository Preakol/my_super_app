defmodule MySuperAppWeb.PictureController do
  @moduledoc false

  use MySuperAppWeb, :controller

  import MySuperAppWeb.ImageHelpers

  alias MySuperApp.{Blog, Blog.Picture, Blog.Post, Repo}

  action_fallback MySuperAppWeb.FallbackController

  def index(conn, %{"start_date" => _start_date, "end_date" => _end_date} = params) do
    case fetch_pictures(params) do
      [_ | _] = pictures ->
        render(conn, :index, paths: pictures)

      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Bad pattern for date and time, right pattern: yyyy-mm-ddThh:mm:ssZ"})
    end
  end

  def index(conn, %{"date" => _date} = params) do
    case fetch_pictures(params) do
      [_ | _] = pictures ->
        render(conn, :index, paths: pictures)

      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Bad pattern for date and time, right pattern: yyyy-mm-ddThh:mm:ssZ"})
    end
  end

  def index(conn, params) do
    case fetch_pictures(params) do
      [_ | _] = pictures ->
        render(conn, :index, pictures: pictures)

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{data: [], message: "No matching records found", status: "not_found"})
    end
  end

  defp fetch_pictures(params) when map_size(params) == 0 do
    Blog.list_pictures()
  end

  defp fetch_pictures(%{"author_email" => author_email}) do
    Blog.get_pictures_by_author_email(author_email)
  end

  defp fetch_pictures(%{"author_name" => author_name}) do
    Blog.get_pictures_by_author_name(author_name)
  end

  defp fetch_pictures(%{"start_date" => start_date, "end_date" => end_date, "order_by" => order_by, "dir" => dir}) do
    Blog.get_pictures_by_period(start_date, end_date, [{String.to_atom(dir), order_by}])
  end

  defp fetch_pictures(%{"start_date" => start_date, "end_date" => end_date}) do
    Blog.get_pictures_by_period(start_date, end_date)
  end

  defp fetch_pictures(%{"date" => date, "order_by" => order_by, "dir" => dir}) do
    Blog.get_pictures_by_date(date, [{String.to_atom(dir), order_by}])
  end

  defp fetch_pictures(%{"date" => date}) do
    Blog.get_pictures_by_date(date)
  end

  defp fetch_pictures(%{"order_by" => order_by, "dir" => dir}) do
    Blog.list_pictures([{String.to_atom(dir), order_by}])
  end

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
    with %Post{} <- Repo.get(Post, post_id), nil <- Repo.get_by(Picture, post_id: post_id) do
      {:ok, picture} = upload_and_create_picture(file, post_id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/posts/#{picture}")
      |> render(:show, picture: picture)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no post with id #{post_id}."})

      _ ->
        conn
        |> put_status(409)
        |> json(%{error: "Picture for post with id #{post_id} already exists."})
    end
  end

  def create(conn, %{"file" => file}) do
    {:ok, picture} = upload_and_create_picture(file, "")

    conn
    |> put_status(:created)
    |> put_resp_header("location", ~p"/api/posts/#{picture}")
    |> render(:show, picture: picture)
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
        picture
        |> delete_picture_from_cloud()

        attrs =
          get_filename_and_format(file.filename)
          |> upload_picture_to_cloud(file.path)
          |> elem(1)
          |> get_picture_attrs(picture.post_id)

        {:ok, updated_picture} = Blog.update_picture(picture, attrs)
        conn
        |> put_status(:ok)
        |> render(:show, picture: updated_picture)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no picture with id #{id}."})
    end
  end

  defp upload_and_create_picture(file, post_id) do
    get_filename_and_format(file.filename)
    |> upload_picture_to_cloud(file.path)
    |> elem(1)
    |> get_picture_attrs(post_id)
    |> Blog.create_picture()
  end
end
