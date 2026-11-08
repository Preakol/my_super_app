defmodule MySuperAppWeb.PostController do
  @moduledoc false

  use MySuperAppWeb, :controller

  alias MySuperApp.{Blog, Blog.Post, Repo, User}

  action_fallback MySuperAppWeb.FallbackController

  def index(conn, params) do
    posts = fetch_posts(params)
    render(conn, :index, posts: posts)
  end

  defp fetch_posts(%{"start_date" => start_date, "end_date" => end_date, "order_by" => order_by, "dir" => dir}) do
    Blog.get_posts_by_period(start_date, end_date, [{String.to_atom(dir), order_by}])
  end

  defp fetch_posts(%{"start_date" => start_date, "end_date" => end_date}) do
    Blog.get_posts_by_period(start_date, end_date)
  end

  defp fetch_posts(%{"date" => date, "order_by" => order_by, "dir" => dir}) do
    Blog.get_posts_by_date(date, [{String.to_atom(dir), order_by}])
  end

  defp fetch_posts(%{"date" => date}) do
    Blog.get_posts_by_date(date)
  end

  defp fetch_posts(%{"order_by" => order_by, "dir" => dir}) do
    Blog.list_posts([{String.to_atom(dir), order_by}])
  end

  defp fetch_posts(_params) do
    Blog.list_posts()
  end

  def create(conn, %{"post" => post_params}) do
    with  %User{} = _user <- Repo.get_by(User, id: post_params["user_id"]),
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
