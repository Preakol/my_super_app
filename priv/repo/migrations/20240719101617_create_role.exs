defmodule MySuperApp.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string
      add :permissions, :integer
      timestamps(type: :utc_datetime)
      add :operator_id, references(:operators, on_delete: :delete_all)
    end
  end
end
