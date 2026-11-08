defmodule MySuperAppWeb.PostJSON do
  alias MySuperApp.Blog.{Post}

  @doc """
  Renders a list of posts.
  """
  def index(%{posts: posts}) do
    %{data: for(post <- posts, do: data(post))}
  end

  @doc """
  Renders a single post.
  """
  def show(%{post: post}) do
    %{data: data(post)}
  end

  defp data(%Post{} = post) do
    %{
      id: post.id,
      title: post.title,
      body: post.body,
      user_id: post.user_id,
      tags: Enum.map(post.tags, &%{id: &1.id, title: &1.title}),
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end
end
