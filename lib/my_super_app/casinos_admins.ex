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
    changeset =
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

    Repo.transaction(fn ->
      with {:ok, operator} <- Repo.insert(changeset),
           {:ok, user} <- fetch_user_without_role(attrs["user_id"]),
           {:ok, _user} <- Accounts.update_user_role(user.id, head_role_id(operator)) do
        operator
      else
        {:error, %Ecto.Changeset{data: %Operator{}} = invalid} ->
          Repo.rollback(invalid)

        {:error, _reason} ->
          changeset
          |> Map.put(:action, :insert)
          |> Ecto.Changeset.add_error(:user_id, "select a user without a role")
          |> Repo.rollback()
      end
    end)
    |> case do
      {:ok, operator} -> {:ok, AdminPubSub.broadcast(operator, :create)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp fetch_user_without_role(user_id) do
    with {:ok, id} <- parse_id(user_id),
         %{role: nil} = user <- Accounts.get_user(id) do
      {:ok, user}
    else
      _ -> {:error, :invalid_user}
    end
  end

  defp head_role_id(operator), do: Enum.find(operator.roles, &(&1.permissions == 2)).id

  def get_operator(id) do
    with {:ok, id} <- parse_id(id),
         %Operator{} = operator <- Repo.get(Operator, id) do
      {:ok, Map.from_struct(operator)}
    else
      _ -> {:error, :not_found}
    end
  end

  defp parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_id(_id), do: :error

  def delete_operator(id) do
    Operator
    |> Repo.get(id)
    |> Repo.delete()
    |> AdminPubSub.broadcast(:delete)
  end
end
