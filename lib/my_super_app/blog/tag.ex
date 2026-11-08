defmodule MySuperApp.Blog.Tag do
  @moduledoc false
  
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :title, :string
    field :color, :string, default: "popo"

    timestamps(type: :utc_datetime)

    many_to_many :posts, MySuperApp.Blog.Post, join_through: "posts_tags", on_replace: :delete, on_delete: :delete_all

  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:title])
    |> cast_assoc(:posts)
    |> validate_required([:title])
  end
end
