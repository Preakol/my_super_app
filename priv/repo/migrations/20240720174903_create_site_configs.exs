defmodule MySuperApp.Repo.Migrations.CreateSiteConfigs do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:site_configs) do
      add :brand, :string
      add :status, :boolean
      add :operator_id, references(:operators, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:site_configs, [:brand])
  end
end
