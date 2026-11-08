defmodule MySuperApp.Blog.Picture do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "pictures" do
    field :file_name, :string
    field :path, :string
    belongs_to :post, MySuperApp.Blog.Post, foreign_key: :post_id

    timestamps(type: :utc_datetime, inserted_at: false, updated_at: :upload_at)
  end

  @doc false
  def changeset(picture, attrs, opts \\ []) do
    picture
    |> cast(attrs, [:file_name, :path, :post_id])
    |> validate_required([:file_name, :path])
    |> maybe_skip_date_update(opts)
  end

  defp maybe_skip_date_update(changeset, opts) do
    if Keyword.get(opts, :skip_date_update, false) do
      Ecto.Changeset.force_change(changeset, :upload_at, get_field(changeset, :upload_at))
    else
      changeset
    end
  end
end
