defmodule MySuperApp.CasinosAdmins do
  @moduledoc false

  alias MySuperApp.{Operator, Role, Repo, Accounts, AdminPubSub}

  import Ecto.Query

  def get_operators() do
    Repo.all(from op in Operator, select: map(op, [:id, :name, :inserted_at, :updated_at]))
  end

  def get_operator_names() do
    Repo.all(from operator in Operator, select: operator.name)
  end

  def get_operator_names_with_users() do
    from(operator in Operator,
      join: role in assoc(operator, :roles),
      join: user in assoc(role, :users),
      select: operator.name,
      distinct: true
    )
    |> Repo.all()
  end

  def create_operator(attrs \\ %{}) do
    Repo.transaction(fn ->
      {:ok, operator} =
        %Operator{}
        |> Operator.changeset(attrs)
        |> Ecto.Changeset.put_assoc(
          :roles,
          [
            %Role{name: "Head of #{attrs["name"]}", permissions: 2},
            %Role{name: "viewer", permissions: 4},
            %Role{name: "role_manager", permissions: 3}
          ]
        )
        |> Repo.insert()

      attrs["user_id"]
      |> String.to_integer()
      |> Accounts.update_user_role(operator.roles |> Enum.at(0) |> Map.get(:id))

      AdminPubSub.broadcast(operator, :create)
    end)
  end

  def get_operator(""), do: nil

  def get_operator(id) do
    Operator
    |> Repo.get(id)
    |> Map.from_struct()
  end

  def delete_operator(id) do
    Operator
    |> Repo.get(id)
    |> Repo.delete()
    |> AdminPubSub.broadcast(:delete)
  end
end
