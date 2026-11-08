defmodule MySuperApp.Blog.SearchTest do
  use MySuperApp.DataCase, async: true

  import MySuperApp.AccountsFixtures

  alias MySuperApp.{Blog, Repo}

  doctest MySuperApp.Blog.Search

  setup do
    user = user_fixture()

    post = fn title, body ->
      {:ok, post} = Blog.create_post(%{"title" => title, "body" => body, "user_id" => user.id})
      post
    end

    %{
      roles: post.("Roles and permissions", "Who can see which admin page."),
      release: post.("Release notes", "Sorting and filtering for the role tables."),
      brands: post.("Brands", "How a site config links a brand to an operator.")
    }
  end

  defp titles(posts), do: Enum.map(posts, & &1.title)

  test "matches stemmed words in titles and bodies", %{roles: roles, release: release} do
    assert Blog.search_posts("permission") |> titles() == [roles.title]
    assert Blog.search_posts("filtered") |> titles() == [release.title]
  end

  test "ranks title matches above body matches", %{roles: roles, release: release} do
    assert Blog.search_posts("role") |> titles() == [roles.title, release.title]
  end

  test "matches word prefixes while typing and requires every word", %{brands: brands} do
    assert Blog.search_posts("ope") |> titles() == [brands.title]
    assert Blog.search_posts("brand oper") |> titles() == [brands.title]
    assert Blog.search_posts("brand roles") == []
  end

  test "keeps the search vector in sync with updates", %{brands: brands} do
    {:ok, _post} =
      Blog.update_post(brands, %{"title" => "Casino brands", "user_id" => brands.user_id})

    assert Blog.search_posts("casino") |> titles() == ["Casino brands"]
  end

  test "ignores tsquery syntax and blank input" do
    assert Blog.search_posts("roles & | ! :* ( '") |> length() == 2
    assert Blog.search_posts("   ") == []
  end

  test "the GIN index backs the search" do
    %{rows: rows} =
      Repo.query!(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'posts' AND indexdef ILIKE '%using gin%'"
      )

    assert [[definition]] = rows
    assert definition =~ "search_vector"
  end
end
