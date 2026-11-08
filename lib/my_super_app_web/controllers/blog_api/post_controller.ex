defmodule MySuperAppWeb.PostController do
  @moduledoc false

  use MySuperAppWeb, :controller

  alias MySuperApp.{Blog, Blog.Post, Repo, User}
  alias MySuperAppWeb.SortParams

  action_fallback MySuperAppWeb.FallbackController

  def index(conn, params) do
    with {:ok, sorting} <- SortParams.parse(params, Blog.post_sort_options(), []),
         posts when is_list(posts) <- fetch_posts(params, sorting) do
      render(conn, :index, posts: posts)
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid date, expected ISO 8601 such as 2024-05-01T12:00:00Z"})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  defp fetch_posts(%{"q" => text}, _sorting) when is_binary(text), do: Blog.search_posts(text)

  defp fetch_posts(%{"start_date" => start_date, "end_date" => end_date}, sorting),
    do: Blog.get_posts_by_period(start_date, end_date, sorting)

  defp fetch_posts(%{"date" => date}, sorting), do: Blog.get_posts_by_date(date, sorting)

  defp fetch_posts(_params, sorting), do: Blog.list_posts(sorting)

  def create(conn, %{"post" => post_params}) do
    with %User{} = _user <- Repo.get_by(User, id: post_params["user_id"]),
         {:ok, %Post{} = post} <- Blog.create_post(post_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/posts/#{post}")
      |> render(:show, post: post)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User with id #{post_params["user_id"]} not found"})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create post."})
    end
  end

  def show(conn, %{"id" => id}) do
    case Blog.get_post(id) do
      %Post{} = post ->
        render(conn, :show, post: post)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Post with id #{id} not found"})
    end
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    with %Post{} = post <- Blog.get_post(id),
         {:ok, %Post{} = updated_post} <- Blog.update_post(post, post_params) do
      render(conn, :show, post: updated_post)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Post with id #{id} not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Couldn't update post", reason: reason})
    end
  end

  def delete(conn, %{"id" => id}) do
    post = Blog.get_post(id)

    with {:ok, %Post{}} <- Blog.delete_post(post) do
      send_resp(conn, :no_content, "")
    end
  end
end
