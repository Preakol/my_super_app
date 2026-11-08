defmodule MySuperAppWeb.PostControllerTest do
  use MySuperAppWeb.ConnCase

  import MySuperApp.BlogFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all posts", %{conn: conn} do
      post_fixture()

      conn = get(conn, ~p"/api/posts")
      assert json_response(conn, 200)["data"] != []
    end

    test "lists posts by date", %{conn: conn} do
      post = post_fixture()

      conn = get(conn, ~p"/api/posts?date=#{DateTime.to_iso8601(post.inserted_at)}")
      assert json_response(conn, 200)["data"] != []
    end
  end

  describe "create" do

    test "creates a post", %{conn: conn} do
      post = post_fixture()
      post_params = %{
        "title" => "Test Title",
        "body" => "Test Body",
        "user_id" => post.user_id
      }

      conn = post(conn, ~p"/api/posts", post: post_params)
      assert %{"id" => _} = json_response(conn, 201)["data"]
    end

    test "returns 404 when user is not found", %{conn: conn} do
      post_params = %{
        "title" => "Test Title",
        "body" => "Test Body",
        "user_id" => -1
      }

      conn = post(conn, ~p"/api/posts", post: post_params)
      assert %{"error" => "User with id -1 not found"} = json_response(conn, 404)
    end
  end

  describe "show" do
    test "shows a post", %{conn: conn} do
      post = post_fixture()
      post_id = post.id

      conn = get(conn, ~p"/api/posts/#{post_id}")
      assert %{"id" => ^post_id} = json_response(conn, 200)["data"]
    end

    test "returns 404 if post not found", %{conn: conn} do
      conn = get(conn, ~p"/api/posts/-1")
      assert json_response(conn, 404)["error"] == "Post with id -1 not found"
    end
  end

  describe "update" do
    test "updates a post", %{conn: conn} do
      post = post_fixture()
      updated_params = %{"title" => "Updated Title", "user_id" => post.user_id}

      conn = put(conn, ~p"/api/posts/#{post.id}", post: updated_params)
      assert json_response(conn, 200)["data"]["title"] == "Updated Title"
    end

    test "returns 404 if post not found", %{conn: conn} do
      conn = put(conn, ~p"/api/posts/-1", post: %{"title" => "Updated Title"})
      assert json_response(conn, 404)["error"] == "Post with id -1 not found"
    end
  end

  describe "delete" do
    test "deletes a post", %{conn: conn} do
      post = post_fixture()

      conn = delete(conn, ~p"/api/posts/#{post.id}")
      assert response(conn, 204)
    end
  end
end
