defmodule MySuperApp.Repo.Migrations.AddUniqueIndexToRoles do
  use Ecto.Migration

  def change do
    create unique_index(:roles, [:name, :operator_id], name: :unique_role_name_per_operator)
  end
end
