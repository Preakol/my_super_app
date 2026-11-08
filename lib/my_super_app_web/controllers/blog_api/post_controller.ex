defmodule MySuperAppWeb.PostController do
  @moduledoc false

  use MySuperAppWeb, :controller

  alias MySuperApp.{Blog, Blog.Post, Repo, User}

  action_fallback MySuperAppWeb.FallbackController

  @directions %{"asc" => :asc, "desc" => :desc}

  def index(conn, params) do
    case parse_sorting(params) do
      {:ok, sorting} ->
        render(conn, :index, posts: fetch_posts(params, sorting))

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  defp parse_sorting(%{"order_by" => order_by, "dir" => dir}) do
    cond do
      not Map.has_key?(@directions, dir) ->
        {:error, "dir must be one of: asc, desc"}

      order_by not in Blog.post_sort_options() ->
        {:error, "order_by must be one of: " <> Enum.join(Blog.post_sort_options(), ", ")}

      true ->
        {:ok, [{Map.fetch!(@directions, dir), order_by}]}
    end
  end

  defp parse_sorting(_params), do: {:ok, []}

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
