defmodule MySuperAppWeb.PictureControllerTest do
  use MySuperAppWeb.ConnCase

  import MySuperApp.BlogFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all pictures", %{conn: conn} do
      picture_fixture()

      conn = get(conn, ~p"/api/pictures")
      assert json_response(conn, 200)["data"] != []
    end

    test "lists pictures by date", %{conn: conn} do
      picture = picture_fixture()

      conn = get(conn, ~p"/api/pictures?date=#{DateTime.to_iso8601(picture.upload_at)}")
      assert json_response(conn, 200)["paths"] != []
    end
  end

  describe "show" do
    test "shows a picture", %{conn: conn} do
      picture = picture_fixture()
      picture_path = picture.path

      conn = get(conn, ~p"/api/pictures/#{picture.id}")
      assert %{"path" => ^picture_path} = json_response(conn, 200)
    end

    test "returns 404 if picture not found", %{conn: conn} do
      conn = get(conn, ~p"/api/pictures/-1")
      assert json_response(conn, 404)["error"] == "Post with id: -1, not found"
    end
  end

  describe "create" do
    test "creates a picture assigning it to post", %{conn: conn} do
      post = post_fixture()
      file = %Plug.Upload{filename: "test_image.jpg", path: "test/support/uploads/test_image.jpg"}

      conn = post(conn, ~p"/api/pictures", %{file: file, post_id: post.id})
      assert %{"id" => _} = json_response(conn, 201)["data"]
    end

    test "creates a picture without assigning it to post", %{conn: conn} do
      file = %Plug.Upload{filename: "test_image.jpg", path: "test/support/uploads/test_image.jpg"}

      conn = post(conn, ~p"/api/pictures", %{file: file})
      assert %{"id" => _} = json_response(conn, 201)["data"]
    end

    test "returns 404 when post is not found", %{conn: conn} do
      file = %Plug.Upload{filename: "test_image.jpg", path: "test/support/uploads/test_image.jpg"}

      conn = post(conn, ~p"/api/pictures", %{file: file, post_id: -1})
      assert %{"error" => "There is no post with id -1."} = json_response(conn, 404)
    end

    test "returns 409 if picture for post already exists", %{conn: conn} do
      picture = picture_fixture()

      file = %Plug.Upload{filename: "test_image.jpg", path: "test/support/uploads/test_image.jpg"}
      conn = post(conn, ~p"/api/pictures", %{file: file, post_id: picture.post_id})

      assert json_response(conn, 409)["error"] == "Picture for post with id #{picture.post_id} already exists."
    end
  end

  describe "update" do
    test "updates a picture", %{conn: conn} do
      picture = picture_fixture()
      file = %Plug.Upload{filename: "updated_image.jpg", path: "test/support/uploads/updated_image.jpg"}

      conn = put(conn, ~p"/api/pictures/#{picture.id}", %{file: file})
      assert json_response(conn, 200)["data"]["file_name"] == "updated_image.jpg"
    end

    test "returns 404 if picture not found", %{conn: conn} do
      file = %Plug.Upload{filename: "updated_image.jpg", path: "test/support/uploads/updated_image.jpg"}

      conn = put(conn, ~p"/api/pictures/-1", %{file: file})
      assert json_response(conn, 404)["error"] == "There is no picture with id -1."
    end
  end
end
