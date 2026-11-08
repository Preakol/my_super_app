defmodule MySuperApp.AccountsFixtures do
  @moduledoc "Users for tests, optionally attached to a role with a given permission level."

  alias MySuperApp.{Accounts, Operator, Repo, Role}

  def unique_login, do: "user#{System.unique_integer([:positive])}"

  def user_fixture(attrs \\ %{}) do
    login = unique_login()

    {:ok, user} =
      attrs
      |> Enum.into(%{login: login, email: "#{login}@example.com", password: "valid-password-123"})
      |> Accounts.register_user()

    user
  end

  @doc """
  A user whose role grants `permissions` (1 = super admin, 2 = main operator
  admin, 3+ = operator staff), as computed in the session query.
  """
  def admin_fixture(permissions, attrs \\ %{}) do
    operator = Repo.insert!(%Operator{name: "Operator #{System.unique_integer([:positive])}"})

    role =
      Repo.insert!(%Role{
        name: "Role #{permissions}",
        permissions: permissions,
        operator_id: operator.id
      })

    attrs
    |> user_fixture()
    |> Ecto.Changeset.change(role_id: role.id)
    |> Repo.update!()
  end
end
