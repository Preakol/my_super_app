defmodule MySuperAppWeb.TagJSON do
  alias MySuperApp.Blog.Tag

  @doc """
  Renders a list of tags.
  """
  def index(%{tags: tags}) do
    %{data: for(tag <- tags, do: data(tag))}
  end

  @doc """
  Renders a single tag.
  """
  def show(%{tag: tag}) do
    %{data: data(tag)}
  end

  defp data(%Tag{} = tag) do
    %{
      id: tag.id,
      title: tag.title,
      posts: Enum.map(tag.posts, &%{id: &1.id, title: &1.title})
    }
  end
end
