defmodule MySuperApp.Blog do
  @moduledoc """
  The Blog context.
  """

  import Ecto.Query, warn: false

  alias MySuperApp.{Blog.Post, Blog.Search, Blog.Tag, Blog.Picture, User, Repo, AdminPubSub}

  @doc """
  Returns the list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts(sorting \\ []) do
    from(p in Post,
      preload: [:tags, :user, :picture]
    )
    |> add_sorting(sorting)
    |> Repo.all()
  end

  def list_posts_by_filters(%{
        search: search,
        author: author,
        tags: tags,
        sorting: sorting_params
      }) do
    from(p in Post, preload: [:tags, :user, :picture])
    |> Search.filter(search)
    |> add_author_filter(author)
    |> add_tags_filter(tags)
    |> add_sorting(sorting_params)
    |> Repo.all()
  end

  @doc """
  Full-text search over post titles and bodies, best match first.
  Blank text returns no posts.
  """
  def search_posts(text) when is_binary(text) do
    from(p in Post, preload: [:tags, :user, :picture])
    |> Search.ranked(text)
    |> Repo.all()
  end

  @doc "Columns posts can be sorted by, as accepted by the `sorting` arguments."
  def post_sort_options,
    do: ["Updated At", "Published At", "Title", "Author", "Post Content Length"]

  def get_authors() do
    from(u in User,
      join: p in assoc(u, :posts),
      distinct: u.login,
      select: u.login
    )
    |> Repo.all()
  end

  @doc "Posts created at exactly `date` (ISO 8601), or `{:error, :invalid_date}`."
  def get_posts_by_date(date, sorting \\ []) do
    with {:ok, date} <- parse_datetime(date) do
      from(p in Post,
        where: p.inserted_at == ^date,
        preload: [:tags, :user]
      )
      |> add_sorting(sorting)
      |> Repo.all()
    end
  end

  @doc "Posts created between two ISO 8601 datetimes, or `{:error, :invalid_date}`."
  def get_posts_by_period(start_date, end_date, sorting \\ []) do
    with {:ok, start_date} <- parse_datetime(start_date),
         {:ok, end_date} <- parse_datetime(end_date) do
      from(p in Post,
        where: p.inserted_at >= ^start_date and p.inserted_at <= ^end_date,
        preload: [:tags, :user]
      )
      |> add_sorting(sorting)
      |> Repo.all()
    end
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> {:error, :invalid_date}
    end
  end

  defp parse_datetime(_value), do: {:error, :invalid_date}

  def get_post_titles_by_user(user) do
    from(p in Post,
      left_join: picture in assoc(p, :picture),
      where: p.user_id == ^user.id or ^user.permissions == 1,
      order_by: [{:asc, p.title}],
      select: %{
        key: p.title,
        value: p.id,
        picture: picture.file_name,
        disabled: not is_nil(picture)
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets a single post.

  Returns nil if the Post does not exist.

  ## Examples

      iex> get_post(123)
      %Post{}

      iex> get_post(456)
      nil

  """
  def get_post(id) do
    Post
    |> Repo.get(id)
    |> Repo.preload([:tags, :user])
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> preload_post_assocs()
    |> AdminPubSub.broadcast()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
    |> preload_post_assocs()
    |> AdminPubSub.broadcast()
  end

  # `tags` is only put on the changeset when the params contain it, so a post
  # created without tags would come back with the association not loaded.
  defp preload_post_assocs({:ok, %Post{} = post}), do: {:ok, Repo.preload(post, [:tags, :user])}
  defp preload_post_assocs({:error, _changeset} = error), do: error

  def update_published_at(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update!()
    |> Repo.preload(:user)
    |> AdminPubSub.broadcast(:publish_update)
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
    |> AdminPubSub.broadcast()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  def tags_with_posts do
    from(t in Tag,
      where:
        fragment(
          """
            EXISTS (
              SELECT 1
              FROM posts_tags
              WHERE posts_tags.tag_id = ?
            )
          """,
          t.id
        ),
      order_by: [{:asc, t.title}],
      select: t.title
    )
    |> Repo.all()
  end

  def tags_with_pictures do
    from(t in Tag,
      where:
        fragment(
          """
            EXISTS (
              SELECT 1
              FROM posts_tags
              JOIN posts ON posts.id = posts_tags.post_id
              JOIN pictures ON pictures.post_id = posts.id
              WHERE posts_tags.tag_id = ?
            )
          """,
          t.id
        ),
      order_by: [{:asc, t.title}],
      select: t.title
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of tags.

  ## Examples

      iex> list_tags()
      [%Tag{}, ...]

  """
  def list_tags do
    from(t in Tag, preload: [:posts])
    |> Repo.all()
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.

  ## Examples

      iex> get_tag!(123)
      %Tag{}

      iex> get_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag!(id) do
    Tag
    |> Repo.get!(id)
    |> Repo.preload(:posts)
  end

  @doc """
  Creates a tag.

  ## Examples

      iex> create_tag(%{field: value})
      {:ok, %Tag{}}

      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{data: %Tag{}}

  """
  def change_tag(attrs \\ %{}) do
    Tag.changeset(%Tag{}, attrs)
  end

  @doc "Columns pictures can be sorted by, as accepted by the `sorting` arguments."
  def picture_sort_options, do: ["Upload At", "File Name"]

  def default_picture_sorting, do: [{:desc, "Upload At"}]

  def list_pictures(sorting \\ default_picture_sorting()) do
    from(pic in Picture,
      left_join: post in assoc(pic, :post),
      preload: [post: post]
    )
    |> add_sorting(sorting)
    |> Repo.all()
  end

  def get_pictures_by_date(date, sorting \\ default_picture_sorting()) do
    case DateTime.from_iso8601(date) do
      {_, date, _} ->
        from(p in Picture,
          where: p.upload_at == ^date
        )
        |> add_sorting(sorting)
        |> Repo.all()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_pictures_by_period(start_date, end_date, sorting \\ default_picture_sorting()) do
    with {_, start_date, _} <- DateTime.from_iso8601(start_date),
         {_, end_date, _} <- DateTime.from_iso8601(end_date) do
      from(p in Picture,
        where: p.upload_at >= ^start_date and p.upload_at <= ^end_date
      )
      |> add_sorting(sorting)
      |> Repo.all()
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_pictures_by_author_name(name) do
    from(picture in Picture,
      join: post in assoc(picture, :post),
      join: user in assoc(post, :user),
      where: user.login == ^name
    )
    |> Repo.all()
  end

  def get_pictures_by_author_email(email) do
    from(picture in Picture,
      join: post in assoc(picture, :post),
      join: user in assoc(post, :user),
      where: user.email == ^email
    )
    |> Repo.all()
  end

  def list_pictures_by_filters(%{
        search: search,
        tags: tags,
        extension: extension,
        sorting: sorting_params
      }) do
    from(picture in Picture,
      left_join: post in assoc(picture, :post),
      left_join: user in assoc(post, :user),
      where: ilike(picture.file_name, ^"%#{extension}"),
      preload: [post: {post, user: user}]
    )
    |> add_pic_search_filter(search)
    |> add_pictures_tags_filter(tags)
    |> add_sorting(sorting_params)
    |> Repo.all()
  end

  def list_picture_extensions() do
    Picture
    |> select([p], p.file_name)
    |> Repo.all()
    |> Enum.map(&Path.extname(&1))
    |> Enum.uniq()
    |> Enum.map(fn "." <> ext = dot_ext -> %{key: ext, value: dot_ext} end)
  end

  def get_picture(id) do
    Repo.get(Picture, id)
    |> Repo.preload(:post)
  end

  def get_picture_by_post_id(post_id), do: Repo.get_by(Picture, post_id: post_id)

  @doc """
  Creates a picture.

  ## Examples

      iex> create_picture(%{field: value})
      {:ok, %Picture{}}

      iex> create_picture(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_picture(attrs \\ %{}) do
    %Picture{}
    |> Picture.changeset(attrs)
    |> Repo.insert()
    |> AdminPubSub.broadcast()
  end

  @doc """
  Updates a picture.

  ## Examples

      iex> update_picture(picture, %{field: new_value})
      {:ok, %Picture{}}

      iex> update_picture(picture, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_picture(%Picture{} = picture, attrs, opts \\ []) do
    picture
    |> Picture.changeset(attrs, opts)
    |> Repo.update()
    |> AdminPubSub.broadcast()
  end

  @doc """
  Deletes a picture.

  ## Examples

      iex> delete_picture(picture)
      {:ok, %Picture{}}

      iex> delete_picture(picture)
      {:error, %Ecto.Changeset{}}

  """
  def delete_picture(%Picture{} = picture) do
    Repo.delete(picture)
    |> AdminPubSub.broadcast()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking picture changes.

  ## Examples

      iex> change_picture(picture)
      %Ecto.Changeset{data: %Picture{}}

  """
  def change_picture(%Picture{} = picture, attrs \\ %{}) do
    Picture.changeset(picture, attrs)
  end

  defp add_author_filter(query, "All Authors"), do: query

  defp add_author_filter(query, author) do
    from(p in query,
      join: u in assoc(p, :user),
      where: u.login == ^author
    )
  end

  defp add_tags_filter(query, []), do: query

  defp add_tags_filter(query, tags) do
    from(p in query,
      join: t in assoc(p, :tags),
      where: t.title in ^tags,
      group_by: p.id,
      having: count(t.id) == ^length(tags)
    )
  end

  defp add_sorting(query, [{direction, "Post Content Length"}]) do
    from(p in query,
      order_by: [{^direction, fragment("LENGTH(?)", p.body)}]
    )
  end

  defp add_sorting(query, [{direction, "Author"}]) do
    from(p in query,
      join: u in assoc(p, :user),
      order_by: [{^direction, u.login}]
    )
  end

  defp add_sorting(query, []) do
    from(p in query,
      order_by: [desc: :updated_at]
    )
  end

  @sort_columns %{
    "Updated At" => :updated_at,
    "Published At" => :published_at,
    "Title" => :title,
    "Upload At" => :upload_at,
    "File Name" => :file_name
  }

  defp add_sorting(query, [{direction, parameter}]) do
    case Map.fetch(@sort_columns, parameter) do
      {:ok, column} -> from(p in query, order_by: ^[{direction, column}])
      :error -> raise ArgumentError, "unknown sort column: #{inspect(parameter)}"
    end
  end

  defp add_pic_search_filter(query, search) do
    case Integer.parse(search) do
      {number, ""} ->
        from(picture in query,
          where: picture.post_id == ^number
        )

      _ ->
        from(picture in query,
          left_join: post in assoc(picture, :post),
          left_join: user in assoc(post, :user),
          where:
            ilike(picture.file_name, ^"#{search}%") or
              ilike(post.title, ^"#{search}%") or
              ilike(user.login, ^"#{search}%") or
              (ilike(user.email, ^"#{search}%") and ^String.contains?(search, "@"))
        )
    end
  end

  defp add_pictures_tags_filter(query, []), do: query

  defp add_pictures_tags_filter(query, tags) do
    from(picture in query,
      where:
        fragment(
          """
            EXISTS (
              SELECT 1
              FROM posts p
              JOIN posts_tags pt ON pt.post_id = p.id
              JOIN tags t ON t.id = pt.tag_id
              WHERE p.id = ? AND t.title = ANY (?)
              GROUP BY p.id
              HAVING COUNT(t.id) = ?
            )
          """,
          picture.post_id,
          ^tags,
          ^length(tags)
        )
    )
  end
end
