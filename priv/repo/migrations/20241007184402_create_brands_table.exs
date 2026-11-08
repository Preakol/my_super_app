defmodule MySuperApp.Repo.Migrations.CreateBrandsTable do
  use Ecto.Migration

  def change do
    create table(:brands) do
      add :name, :string
    end

    create unique_index(:brands, [:name])
  end
end
