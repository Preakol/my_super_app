defmodule MySuperApp.SiteConfig do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_configs" do
    field :brand, :string
    field :status, :boolean, default: true
    belongs_to :operator, MySuperApp.Operator, foreign_key: :operator_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(site_config, attrs) do
    site_config
    |> cast(attrs, [:brand, :status, :operator_id])
    |> validate_required([:brand, :operator_id])
    |> unsafe_validate_unique(:brand, MySuperApp.Repo)
    |> unique_constraint(:brand)
    |> assoc_constraint(:operator)
  end
end
