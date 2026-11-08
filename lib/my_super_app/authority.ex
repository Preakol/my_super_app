defmodule MySuperApp.Authority do
  @moduledoc """
  The Authority context.
  """

  import Ecto.Query, warn: false
  alias MySuperApp.{Repo, Role, AdminPubSub}

  def get_roles() do
    Repo.all(Role)
  end

  def get_roles_by_filters(%{operator: operator, sorting: sorting}) do
    from(role in Role,
      join: operator in assoc(role, :operator),
      where: role.permissions != 1,
      select: %{
        id: role.id,
        name: role.name,
        permissions: role.permissions,
        operator_id: operator.id,
        operator_name: operator.name,
        inserted_at: role.inserted_at,
        updated_at: role.updated_at
      }
    )
    |> add_operator_filter(operator)
    |> add_sorting(sorting)
    |> Repo.all()
  end

  def get_role_names_with_users_by_operator(operator_name) do
    Repo.all(
      from role in Role,
        join: user in assoc(role, :users),
        join: operator in assoc(role, :operator),
        where: operator.name == ^operator_name,
        select: role.name
    )
  end

  def get_roles_by_operator(nil, _), do: []

  def get_roles_by_operator(operator_name, with_main_operator) do
    Repo.all(
      from role in Role,
        join: operator in assoc(role, :operator),
        where: operator.name == ^operator_name and (role.permissions != 2 or ^with_main_operator),
        select: %{
          name: role.name,
          id: role.id
        }
    )
  end

  def get_role(id) do
    Repo.get(Role, id)
  end

  def get_role_by_user_id(user_id) do
    from(role in Role,
      join: user in assoc(role, :users),
      where: user.id == ^user_id
    )
    |> Repo.one()
  end

  def get_role_by_name_and_op_id(name, operator_id) do
    Repo.get_by(Role, name: name, operator_id: operator_id)
  end

  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
    |> AdminPubSub.broadcast(:create)
  end

  def update_role(id, attrs) do
    Repo.get(Role, id)
    |> Role.changeset(attrs)
    |> Repo.update()
    |> AdminPubSub.broadcast(:update)
  end

  def delete_role(id) do
    Role
    |> Repo.get(id)
    |> Repo.delete()
    |> AdminPubSub.broadcast(:delete)
  end

  def change_role(%Role{} = role, attrs \\ %{}), do: Role.changeset(role, attrs)

  defp add_operator_filter(query, operator_name) when operator_name == "All", do: query

  defp add_operator_filter(query, operator_name) do
    from(role in query,
      join: operator in assoc(role, :operator),
      where: operator.name == ^operator_name
    )
  end

  defp add_sorting(query, [{parameter, direction}]) do
    from(role in query,
      order_by: ^[{direction |> String.downcase() |> String.to_atom(), parameter}]
    )
  end
end
