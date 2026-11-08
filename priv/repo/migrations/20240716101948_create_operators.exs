defmodule MySuperApp.Repo.Migrations.CreateOperators do
  use Ecto.Migration

  def change do
    create table(:operators) do
      add :name, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:operators, [:name])
  end
end
