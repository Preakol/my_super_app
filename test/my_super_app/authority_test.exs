defmodule MySuperApp.AuthorityTest do
  use MySuperApp.DataCase

  alias MySuperApp.{Repo, Role, Authority, Accounts, Operator}

  setup do
    {:ok, operator1} = Repo.insert(%Operator{name: "testoperator1"})
    {:ok, operator2} = Repo.insert(%Operator{name: "testoperator2"})

    {:ok, role1} =
      Repo.insert(%Role{name: "TestAdmin1", permissions: 2, operator_id: operator1.id})

    {:ok, role2} =
      Repo.insert(%Role{name: "TestAdmin2", permissions: 3, operator_id: operator1.id})

    {:ok, role3} =
      Repo.insert(%Role{name: "TestAdmin3", permissions: 4, operator_id: operator2.id})

    %{role1: role1, role2: role2, role3: role3, operator1: operator1, operator2: operator2}
  end

  describe "get_roles/0" do
    test "returns all roles", %{role1: role1, role2: role2, role3: role3} do
      assert Authority.get_roles() == [role1, role2, role3]
    end
  end

  describe "get_roles_by_filters/1" do
    test "returns filtered roles", %{role1: role1, role2: role2, operator1: operator1} do
      filters = %{operator: operator1.name, sorting: [name: "ASC"]}
      role1_id = role1.id
      role2_id = role2.id

      assert [%{id: ^role1_id}, %{id: ^role2_id}] = Authority.get_roles_by_filters(filters)
    end
  end

  describe "get_role_names_with_users_by_operator/1" do
    test "returns role names by operator", %{role1: role1, role2: role2, operator1: operator1} do
      Accounts.register_user(%{
        login: "testuser1",
        email: "test@user1.com",
        password: "testuser1",
        role_id: role1.id
      })

      Accounts.register_user(%{
        login: "testuser2",
        email: "test@user2.com",
        password: "testuser2",
        role_id: role2.id
      })

      role1_name = role1.name
      role2_name = role2.name

      assert [^role1_name, ^role2_name] =
               Authority.get_role_names_with_users_by_operator(operator1.name)
    end
  end

  describe "get_roles_by_operator/2" do
    test "returns empty list for nil operator" do
      assert [] == Authority.get_roles_by_operator(nil, false)
    end

    test "returns roles by operator name", %{role3: role3, operator2: operator2} do
      assert Authority.get_roles_by_operator(operator2.name, false) == [
               %{name: role3.name, id: role3.id}
             ]
    end
  end

  describe "get_role/1" do
    test "returns the role by id", %{role1: role1} do
      assert Authority.get_role(role1.id) == role1
    end

    test "returns nil for nonexistent role" do
      assert Authority.get_role(-1) == nil
    end
  end

  describe "get_role_by_user_id/1" do
    test "returns role for a given user id", %{role1: role1} do
      {:ok, user} =
        Accounts.register_user(%{
          login: "testuser",
          email: "test@user.com",
          password: "testuser",
          role_id: role1.id
        })

      assert Authority.get_role_by_user_id(user.id) == role1
    end

    test "returns nil for user without a role" do
      assert Authority.get_role_by_user_id(-1) == nil
    end
  end

  describe "get_role_by_name_and_op_id/2" do
    test "returns the role by name and operator id", %{role1: role1, operator1: operator1} do
      assert Authority.get_role_by_name_and_op_id(role1.name, operator1.id) == role1
    end

    test "returns nil for nonexistent role" do
      assert Authority.get_role_by_name_and_op_id("NonexistentRole", -1) == nil
    end
  end

  describe "create_role/1" do
    test "creates a new role", %{operator1: operator1} do
      attrs = %{name: "New Role", permissions: 4, operator_id: operator1.id}
      assert {:ok, %Role{name: "New Role"}} = Authority.create_role(attrs)
      assert Authority.get_roles() |> Enum.any?(fn r -> r.name == "New Role" end)
    end

    test "returns error for invalid attributes" do
      assert {:error, _changeset} = Authority.create_role(%{name: nil})
    end
  end

  describe "update_role/2" do
    test "updates an existing role", %{role1: role1} do
      assert {:ok, %Role{name: "Updated Role"}} =
               Authority.update_role(role1.id, %{name: "Updated Role"})

      assert Authority.get_role(role1.id).name == "Updated Role"
    end
  end

  describe "delete_role/1" do
    test "deletes a role", %{role1: role1} do
      assert {:ok, %Role{}} = Authority.delete_role(role1.id)
      assert Authority.get_role(role1.id) == nil
    end
  end

  describe "change_role/2" do
    test "returns a changeset for a role", %{role1: role1} do
      changeset = Authority.change_role(role1, %{name: "Updated Role"})
      assert changeset.valid?
      assert changeset.changes.name == "Updated Role"
    end
  end
end
