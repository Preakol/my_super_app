defmodule MySuperAppWeb.RoleJSON do

  @doc """
  Renders a list of roles.
  """
  def index(%{roles: roles}) do
    %{data: for(role <- roles, do: data(role))}
  end

  @doc """
  Renders a single role.
  """
  def show(%{role: role}) do
    %{data: data(role)}
  end

  defp data(%{} = role) do
    %{
      id: role.id,
      name: role.name,
      operator_id: role.operator_id,
      permissions: role.permissions,
      inserted_at: role.inserted_at,
      updated_at: role.updated_at
    }
  end
end
