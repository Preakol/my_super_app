defmodule MySuperApp.Repo.Migrations.CreatePictures do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:pictures) do
      add :file_name, :string
      add :path, :string
      add :post_id, references(:posts, on_delete: :delete_all), null: true

      timestamps(updated_at: :upload_at, inserted_at: false)
    end
  end
end
