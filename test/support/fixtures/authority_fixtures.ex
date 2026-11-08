defmodule MySuperApp.AuthorityFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MySuperApp.Authority` context.
  """
  alias MySuperApp.{Repo, Operator, Role}

  @doc """
  Generate a post.
  """
  def authority_fixture() do
    operator = %Operator{name: "Test Operator"}
    {:ok, operator} = Repo.insert(operator)

    role1 = %Role{name: "Role1", permissions: 3, operator_id: operator.id}
    role2 = %Role{name: "Role2", permissions: 4, operator_id: operator.id}
    {:ok, role1} = Repo.insert(role1)
    {:ok, role2} = Repo.insert(role2)

    %{operator: operator, role1: role1, role2: role2}
  end
end
