defmodule MySuperAppWeb.Plugs.RequireApiTokenTest do
  use MySuperAppWeb.ConnCase

  import MySuperApp.AccountsFixtures

  @post %{"post" => %{"title" => "Hi", "body" => "Text"}}

  defp json_conn(conn), do: put_req_header(conn, "accept", "application/json")

  test "reads stay public", %{conn: conn} do
    assert conn |> json_conn() |> get(~p"/api/posts") |> json_response(200)
    assert conn |> json_conn() |> get(~p"/api/users") |> json_response(200)
  end

  test "writes without a token get 401", %{conn: conn} do
    user = user_fixture()

    for conn <- [
          post(json_conn(conn), ~p"/api/posts", @post),
          put(json_conn(conn), ~p"/api/users/#{user.id}", %{"user" => %{"login" => "x"}}),
          delete(json_conn(conn), ~p"/api/users/#{user.id}")
        ] do
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
      assert get_resp_header(conn, "www-authenticate") == ["Bearer"]
    end

    assert MySuperApp.Repo.reload(user)
  end

  test "a wrong or malformed token gets 401", %{conn: conn} do
    for header <- ["Bearer wrong", "test-api-token", "Basic test-api-token", "Bearer "] do
      conn = conn |> json_conn() |> put_req_header("authorization", header)
      assert conn |> post(~p"/api/posts", @post) |> json_response(401)
    end
  end

  test "the configured token is accepted", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> json_conn()
      |> put_req_header("authorization", "Bearer test-api-token")
      |> post(~p"/api/posts", put_in(@post, ["post", "user_id"], user.id))

    assert json_response(conn, 201)
  end

  test "rejects every write when no token is configured", %{conn: conn} do
    previous = Application.fetch_env!(:my_super_app, :api_token)
    Application.put_env(:my_super_app, :api_token, nil)
    on_exit(fn -> Application.put_env(:my_super_app, :api_token, previous) end)

    conn = conn |> json_conn() |> put_req_header("authorization", "Bearer ")
    assert conn |> post(~p"/api/posts", @post) |> json_response(401)
  end
end
