defmodule MySuperApp.Repo.Migrations.AddSearchVectorToPosts do
  use Ecto.Migration

  # A stored generated column keeps the vector in sync with title/body without
  # triggers or application code; titles weigh more than bodies in ts_rank.
  def up do
    execute """
    ALTER TABLE posts ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
      ) STORED
    """

    create index(:posts, [:search_vector], using: "GIN")
  end

  def down do
    drop index(:posts, [:search_vector])

    alter table(:posts) do
      remove :search_vector
    end
  end
end
