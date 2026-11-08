defmodule MySuperApp.Role do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :permissions, :integer
    belongs_to :operator, MySuperApp.Operator, foreign_key: :operator_id
    has_many :users, MySuperApp.User, on_replace: :nilify
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions, :operator_id])
    |> validate_required([:name, :permissions, :operator_id])
    |> validate_name()
    |> unsafe_validate_unique([:name, :operator_id], MySuperApp.Repo,
      message: "has already been taken for this operator"
    )
    |> unique_constraint(:name, name: :unique_role_name_per_operator)
    |> assoc_constraint(:operator)
  end

  defp validate_name(changeset) do
    changeset
    |> validate_format(:name, ~r/^[a-zA-Z][^@]*[a-zA-Z][^@]*$/,
      message:
        "must have first alphabetic character no @ sign and at least two alphabetic characters"
    )
    |> validate_length(:name, min: 2, max: 17)
  end
end
