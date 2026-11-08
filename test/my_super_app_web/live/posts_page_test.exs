defmodule MySuperAppWeb.PostsPageTest do
  use MySuperAppWeb.ConnCase

  use Oban.Testing, repo: MySuperApp.Repo

  import Ecto.Query
  import MySuperApp.AccountsFixtures

  alias MySuperApp.{Blog, Blog.Post, Repo}
  alias MySuperAppWeb.PostsPage

  defp create_post(user, attrs \\ %{}) do
    {:ok, post} =
      %{
        "title" => "Hello world",
        "body" => "Body text",
        "user_id" => user.id,
        "tags" => [%{"title" => "news"}]
      }
      |> Map.merge(attrs)
      |> Blog.create_post()

    post
  end

  defp age_post(post) do
    old = DateTime.add(DateTime.utc_now(), -10, :minute) |> DateTime.truncate(:second)
    Repo.update_all(from(p in Post, where: p.id == ^post.id), set: [updated_at: old])
  end

  setup context do
    %{user: author} = admin = log_in_admin(context, 3)
    admin |> Map.put(:post, create_post(author))
  end

  test "lists posts and filters by title, author and tag", %{conn: conn, user: author} do
    other = user_fixture(%{login: "zed"})
    create_post(other, %{"title" => "Other story", "tags" => [%{"title" => "sport"}]})
    {:ok, view, _html} = live(conn, ~p"/admin/posts")

    assert has_element?(view, "article", "Hello world")
    assert has_element?(view, "article", "Other story")

    view |> form("form[phx-change=change_search]", search: "Oth") |> render_change()
    refute has_element?(view, "article", "Hello world")

    view |> element("button", "Clear filters") |> render_click()
    view |> form("form[phx-change=change_author]", author: author.login) |> render_change()
    refute has_element?(view, "article", "Other story")

    view |> element("button", "Clear filters") |> render_click()
    view |> element("#tag-filter button", "SPORT") |> render_click()
    assert has_element?(view, "article", "Other story")
    refute has_element?(view, "article", "Hello world")
  end

  test "creates a post with tags", %{conn: conn, user: author} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("button", "Add new post") |> render_click()

    view
    |> form("#post-form", post: %{title: "Fresh", body: "New body", tag: "elixir"})
    |> render_change()

    view |> element("button[aria-label='Add tag']") |> render_click()
    assert has_element?(view, "#post-form", "elixir")

    assert view
           |> form("#post-form", post: %{title: "Fresh", body: "New body"})
           |> render_submit() =~ "Post created"

    post = Repo.get_by(Post, title: "Fresh") |> Repo.preload(:tags)
    assert post.user_id == author.id
    assert Enum.map(post.tags, & &1.title) == ["ELIXIR"]
  end

  test "edits a post and removes a tag", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("#post-#{post.id} > button") |> render_click()
    view |> element("#post-#{post.id} button", "Edit") |> render_click()

    view |> element("button[aria-label='Remove tag NEWS']") |> render_click()

    assert view |> form("#post-form", post: %{title: "Renamed"}) |> render_submit() =~
             "Post updated"

    post = Blog.get_post(post.id)
    assert post.title == "Renamed"
    assert post.tags == []
  end

  test "requires a title", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("button", "Add new post") |> render_click()

    assert view |> form("#post-form", post: %{title: "", body: "x"}) |> render_submit() =~
             "can&#39;t be blank"
  end

  test "publishing queues an email to the author", %{conn: conn, post: post} do
    age_post(post)
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("#post-#{post.id} > button") |> render_click()

    view |> element("#post-#{post.id} button[role=switch]") |> render_click()

    assert Blog.get_post(post.id).published_at

    assert_enqueued(
      worker: MySuperApp.Jobs.Email,
      args: %{"id" => post.id, "title" => post.title}
    )
  end

  test "a recently changed post can't be (un)published yet", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("#post-#{post.id} > button") |> render_click()

    assert has_element?(view, "#post-#{post.id} button[role=switch][disabled]")
  end

  test "deletes a post after confirmation", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("#post-#{post.id} > button") |> render_click()
    view |> element("#post-#{post.id} button", "Delete") |> render_click()

    assert view |> element("#delete-post-modal-confirm") |> render_click() =~ "Post deleted"
    refute Blog.get_post(post.id)
  end

  test "other people's posts are read-only for staff", %{conn: conn} do
    other_post = create_post(user_fixture(), %{"title" => "Not mine"})
    {:ok, view, _html} = live(conn, ~p"/admin/posts")
    view |> element("#post-#{other_post.id} > button") |> render_click()

    refute has_element?(view, "#post-#{other_post.id} button", "Edit")
  end

  test "publish lock lasts five minutes" do
    now = ~U[2024-01-01 12:00:00Z]
    assert PostsPage.publish_locked?(%Post{updated_at: ~U[2024-01-01 11:56:00Z]}, now)
    refute PostsPage.publish_locked?(%Post{updated_at: ~U[2024-01-01 11:55:00Z]}, now)
  end
end
