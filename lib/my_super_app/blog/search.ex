defmodule MySuperApp.Blog.Search do
  @moduledoc """
  PostgreSQL full-text search over posts, backed by the generated
  `posts.search_vector` column and its GIN index.
  """

  import Ecto.Query, only: [from: 2]

  @doc """
  Turns free text into an English prefix tsquery, so results update while
  the user is still typing a word. Anything that is not a letter or a digit
  is dropped, which keeps tsquery operators out of user input.

      iex> MySuperApp.Blog.Search.prefix_tsquery("Release notes")
      {:ok, "release:* & notes:*"}

      iex> MySuperApp.Blog.Search.prefix_tsquery("roles & (perm!")
      {:ok, "roles:* & perm:*"}

      iex> MySuperApp.Blog.Search.prefix_tsquery("  ?! ")
      :empty
  """
  def prefix_tsquery(text) when is_binary(text) do
    case String.split(text, ~r/[^\p{L}\p{N}]+/u, trim: true) do
      [] -> :empty
      words -> {:ok, Enum.map_join(words, " & ", &(String.downcase(&1) <> ":*"))}
    end
  end

  @doc "Keeps posts matching `text`; blank text leaves the query unchanged."
  def filter(query, text) do
    case prefix_tsquery(text) do
      {:ok, tsquery} ->
        from(p in query,
          where: fragment("? @@ to_tsquery('english', ?)", p.search_vector, ^tsquery)
        )

      :empty ->
        query
    end
  end

  @doc "Like `filter/2`, ordered by relevance (best match first). Blank text matches nothing."
  def ranked(query, text) do
    case prefix_tsquery(text) do
      {:ok, tsquery} ->
        from(p in query,
          where: fragment("? @@ to_tsquery('english', ?)", p.search_vector, ^tsquery),
          order_by: [
            desc: fragment("ts_rank(?, to_tsquery('english', ?))", p.search_vector, ^tsquery),
            desc: p.updated_at
          ]
        )

      :empty ->
        from(p in query, where: false)
    end
  end
end
