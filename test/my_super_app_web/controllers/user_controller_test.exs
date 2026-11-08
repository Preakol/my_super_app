defmodule MySuperAppWeb.UserControllerTest do
  use MySuperAppWeb.ConnCase

  setup :authorize_api

  alias MySuperApp.{Accounts, Repo, User}

  @create_attrs %{email: "test@example.com", login: "test_user", password: "password123"}
  @update_attrs %{
    email: "updated@example.com",
    login: "updated_user",
    password: "new_password123"
  }
  @invalid_attrs %{email: "invalidemail.com", login: "inv@lid_login", password: "?"}

  describe "index/2" do
    test "lists all users", %{conn: conn} do
      Accounts.register_user(@create_attrs)
      conn = get(conn, ~p"/api/users")
      assert json_response(conn, 200)["data"] != []
    end
  end

  describe "show/2 by id" do
    test "shows a user by id", %{conn: conn} do
      {:ok, user} = Accounts.register_user(@create_attrs)
      conn = get(conn, ~p"/api/users/#{user.id}")

      assert json_response(conn, 200)["data"] == %{
               "id" => user.id,
               "login" => user.login,
               "email" => user.email,
               "inserted_at" => user.inserted_at |> DateTime.to_iso8601()
             }
    end

    test "returns 404 when user id is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/users/-1")
      assert json_response(conn, 404)["error"] == "User with id -1 not found"
    end
  end

  describe "show/2 by email" do
    test "shows a user by email", %{conn: conn} do
      {:ok, user} = Accounts.register_user(@create_attrs)
      conn = get(conn, ~p"/api/users/by_email/#{user.email}")

      assert json_response(conn, 200)["data"] == %{
               "id" => user.id,
               "login" => user.login,
               "email" => user.email,
               "inserted_at" => user.inserted_at |> DateTime.to_iso8601()
             }
    end

    test "returns 404 when user email is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/users/by_email/nonexistent@example.com")

      assert json_response(conn, 404)["error"] ==
               "User with email nonexistent@example.com not found"
    end
  end

  describe "show/2 by name" do
    test "shows a user by name", %{conn: conn} do
      {:ok, user} = Accounts.register_user(@create_attrs)
      conn = get(conn, ~p"/api/users/by_name/#{user.login}")

      assert json_response(conn, 200)["data"] == %{
               "id" => user.id,
               "login" => user.login,
               "email" => user.email,
               "inserted_at" => user.inserted_at |> DateTime.to_iso8601()
             }
    end

    test "returns 404 when user name is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/users/by_name/nonexistent_user")
      assert json_response(conn, 404)["error"] == "User with name nonexistent_user not found"
    end
  end

  describe "create/2" do
    test "creates a user", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      user = Repo.get(User, id)
      assert user.email == "test@example.com"
      assert user.login == "test_user"
    end

    test "returns error when specified params aren't acceptable", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: %{somethign_wrong: ":("})

      assert json_response(conn, 422)["error"] ==
               "You need to specify only these required parameters: email, login, password"
    end

    test "returns error when params are invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update/2" do
    setup do
      {:ok, user} = Accounts.register_user(@create_attrs)
      %{user: user}
    end

    test "updates a user", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/api/users/#{user.id}", user: @update_attrs, current_password: "password123")

      user_id = user.id
      assert %{"id" => ^user_id} = json_response(conn, 200)["data"]

      updated_user = Repo.get(User, user.id)
      assert updated_user.email == "updated@example.com"
      assert updated_user.login == "updated_user"
    end

    test "returns 404 when user id is not found", %{conn: conn} do
      conn = put(conn, ~p"/api/users/-1", user: @update_attrs, current_password: "password123")
      assert json_response(conn, 404)["error"] == "User with id -1 not found"
    end

    test "returns error when specified params aren't acceptable", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/api/users/#{user.id}",
          user: %{somethign_wrong: ":("},
          current_password: "password123"
        )

      assert json_response(conn, 422)["error"] ==
               "You need to provide your current_password, and specify one or many of these parameters: email, login, password"
    end

    test "returns error when params are invalid", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/api/users/#{user.id}",
          user: @invalid_attrs,
          current_password: "password123"
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete/2" do
    setup do
      {:ok, user} = Accounts.register_user(@create_attrs)
      %{user: user}
    end

    test "deletes user", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/users/#{user.id}")
      assert response(conn, 204)
      refute Repo.get(User, user.id)
    end

    test "returns 404 when user id is not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/users/-1")
      assert json_response(conn, 404)["error"] == "There is no User with id -1."
    end
  end
end
