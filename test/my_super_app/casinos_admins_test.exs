defmodule MySuperApp.CasinosAdminsTest do
  alias MySuperApp.{CasinosAdmins, Operator, Role, Repo, Accounts}
  use MySuperApp.DataCase

  setup do
    {:ok, operator1} = Repo.insert(%Operator{name: "operator_with_users"})
    {:ok, operator2} = Repo.insert(%Operator{name: "operator_without_users"})

    {:ok, role} = Repo.insert(%Role{name: "TestAdmin", permissions: 2, operator_id: operator1.id})
    {:ok, _} = Accounts.register_user(%{login: "testuser1", email: "test@user1.com", password: "testuser1", role_id: role.id})
    {:ok, user} = Accounts.register_user(%{login: "testuser2", email: "test@user2.com", password: "testuser2"})


    %{operator1: operator1, operator2: operator2, user_without_role: user}
  end

  describe "get_operators/0" do
    test "returns all operators as maps", %{operator1: operator1, operator2: operator2} do
      operator1_id = operator1.id
      operator2_id = operator2.id

      assert [%{id: ^operator1_id}, %{id: ^operator2_id}] = CasinosAdmins.get_operators()
    end
  end

  describe "get_operator_names/0" do
    test "returns only operator names", %{operator1: operator1, operator2: operator2} do
      operator1_name = operator1.name
      operator2_name = operator2.name
      assert [^operator1_name, ^operator2_name] = CasinosAdmins.get_operator_names()
    end
  end

  describe "get_operator_names_with_users/0" do
    test "returns only names of operators that have users", %{operator1: operator1} do
      operator_with_user_name = operator1.name
      assert [operator_with_user_name] == CasinosAdmins.get_operator_names_with_users()
    end
  end

  describe "get_operator/1" do
    test "returns the operator map for a valid ID", %{operator1: operator1} do
      assert Map.from_struct(operator1) == CasinosAdmins.get_operator(operator1.id)
    end

    test "returns nil for an empty string ID" do
      assert CasinosAdmins.get_operator("") == nil
    end
  end

  describe "create_operator/1" do
    test "creates an operator and gives a selected user the main role of this operator", %{user_without_role: user} do
      assert {:ok, operator} = CasinosAdmins.create_operator(%{"name" => "NewOperator", "user_id" => "#{user.id}"})

      assert operator.name == "NewOperator"
      assert operator.id == Accounts.get_user(user.id).role.operator.id

      roles = Repo.all(from r in Role, where: r.operator_id == ^operator.id)
      assert length(roles) == 3
      assert Enum.any?(roles, fn r -> r.name == "Head of NewOperator" and r.permissions == 2 end)
      assert Enum.any?(roles, fn r -> r.name == "viewer" and r.permissions == 4 end)
      assert Enum.any?(roles, fn r -> r.name == "role_manager" and r.permissions == 3 end)
    end
  end

  describe "delete_operator/1" do
    test "deletes an existing operator", %{operator1: operator1} do
      assert {:ok, _deleted_operator} = CasinosAdmins.delete_operator(operator1.id)
      assert Repo.get(Operator, operator1.id) == nil
    end
  end
end
