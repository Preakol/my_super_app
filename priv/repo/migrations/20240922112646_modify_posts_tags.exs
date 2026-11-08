defmodule MySuperApp.Repo.Migrations.ModifyPostsTags do
  use Ecto.Migration

  def change do
    alter table(:posts_tags) do
      modify :post_id, references(:posts, on_delete: :delete_all), from: references(:posts)
    end
  end
end
