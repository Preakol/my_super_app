defmodule MySuperAppWeb.RoleControllerTest do
  use MySuperAppWeb.ConnCase

  alias MySuperApp.{Authority, Accounts, Role, Repo, Operator}

  @operator_attrs %{name: "John Doe"}
  @user_attrs %{login: "testuser", email: "test@user.com", password: "testuser"}
  @valid_role_attrs %{name: "Admin", permissions: 3}
  @invalid_role_attrs %{name: nil, operator_id: nil, permissions: nil}
  @update_role_attrs %{name: "Viewer", permissions: 4}

  setup do
    {:ok, operator} = Operator.changeset(%Operator{}, @operator_attrs) |> Repo.insert()
    %{operator: operator}
  end

  describe "index/2" do
    test "lists all roles when no parameters are provided", %{conn: conn, operator: operator} do
      Authority.create_role(Map.put(@valid_role_attrs, :operator_id, operator.id))
      conn = get(conn, ~p"/api/roles")
      assert json_response(conn, 200)["data"] != []
    end

    test "returns a role by name and operator_id", %{conn: conn, operator: operator} do
      {:ok, role} = Authority.create_role(Map.put(@valid_role_attrs, :operator_id, operator.id))
      conn = get(conn, ~p"/api/roles", name: role.name, operator_id: role.operator_id)
      assert json_response(conn, 200)["data"]["name"] == role.name
    end

    test "returns 404 if role by name and operator_id is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/roles", name: "Nonexistent", operator_id: -1)
      assert json_response(conn, 404)["error"] == "There is no Role addressing such parameters"
    end
  end

  describe "show/2 by id" do
    test "shows a role by id", %{conn: conn, operator: operator} do
      {:ok, role} = Authority.create_role(Map.put(@valid_role_attrs, :operator_id, operator.id))
      conn = get(conn, ~p"/api/roles/#{role.id}")
      assert json_response(conn, 200)["data"]["name"] == role.name
    end

    test "returns 404 when role id is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/roles/-1")
      assert json_response(conn, 404)["error"] == "Role with id -1 not found"
    end
  end

  describe "show/2 by user_id" do
    test "shows a role by operator_id", %{conn: conn, operator: operator} do
      {:ok, role} = Authority.create_role(Map.put(@valid_role_attrs, :operator_id, operator.id))
      {:ok, user} = Accounts.register_user(Map.put(@user_attrs, :role_id, role.id))
      conn = get(conn, ~p"/api/roles/by_user/#{user.id}")
      assert json_response(conn, 200)["data"]["name"] == role.name
    end

    test "returns 404 if role by operator_id is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/roles/by_user/-1")
      assert json_response(conn, 404)["error"] == "Role with user_id -1 not found"
    end
  end

  describe "create/2" do
    test "creates a new role", %{conn: conn, operator: operator} do
      conn =
        post(conn, ~p"/api/roles", role: Map.put(@valid_role_attrs, :operator_id, operator.id))

      assert %{"id" => id} = json_response(conn, 201)["data"]

      role = Repo.get(Role, id)
      assert role.name == "Admin"
    end

    test "returns error when invalid params are provided", %{conn: conn} do
      conn = post(conn, ~p"/api/roles", role: @invalid_role_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns error when permissions are invalid", %{conn: conn, operator: operator} do
      conn = post(conn, ~p"/api/roles", role: %{permissions: 5, operator_id: operator.id})

      assert json_response(conn, 422)["error"] ==
               "You need to specify \"permissions\", options: 3(Gamechanger), 4(Viewer)."
    end
  end

  describe "update/2" do
    setup %{operator: operator} do
      {:ok, role} = Authority.create_role(Map.put(@valid_role_attrs, :operator_id, operator.id))
      %{role: role}
    end

    test "updates a role", %{conn: conn, role: role} do
      conn = put(conn, ~p"/api/roles/#{role.id}", role: @update_role_attrs)
      role_id = role.id
      assert %{"id" => ^role_id} = json_response(conn, 200)["data"]

      updated_role = Repo.get(Role, role.id)
      assert updated_role.name == "Viewer"
    end

    test "returns 404 when role id is not found", %{conn: conn} do
      conn = put(conn, ~p"/api/roles/-1", role: @update_role_attrs)
      assert json_response(conn, 404)["error"] == "Role with id -1 not found"
    end

    test "returns error when permissions are invalid", %{conn: conn, role: role} do
      conn = put(conn, ~p"/api/roles/#{role.id}", role: %{permissions: 5})

      assert json_response(conn, 422)["error"] ==
               "You can only update the name of the Role and permissions, permissions options: 3(Gamechanger), 4(Viewer)."
    end
  end

  describe "delete/2" do
    setup %{operator: operator} do
      {:ok, role} = Authority.create_role(Map.put(@valid_role_attrs, :operator_id, operator.id))
      %{role: role}
    end

    test "deletes a role", %{conn: conn, role: role} do
      conn = delete(conn, ~p"/api/roles/#{role.id}")
      assert response(conn, 204)
      refute Repo.get(Role, role.id)
    end

    test "returns 404 when role id is not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/roles/-1")
      assert json_response(conn, 404)["error"] == "There is no Role with id -1."
    end
  end
end
