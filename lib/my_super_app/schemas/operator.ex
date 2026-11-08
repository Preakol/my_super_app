defmodule MySuperApp.Operator do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "operators" do
    field :name, :string
    timestamps(type: :utc_datetime)
    has_many :roles, MySuperApp.Role, on_delete: :delete_all
    has_many :site_configs, MySuperApp.SiteConfig, on_delete: :delete_all
  end

  @doc false
  def changeset(operator, attrs) do
    operator
    |> cast(attrs, [:name])
    |> cast_assoc(:roles)
    |> validate_required([:name])
    |> validate_length(:name, min: 3, max: 50)
    |> unique_constraint(:name)
  end
end
