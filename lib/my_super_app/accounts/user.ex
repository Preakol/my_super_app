defmodule MySuperApp.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias MySuperApp.{Role, Blog.Post}

  schema "users" do
    field :login, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :avatar_image, :string
    timestamps(type: :utc_datetime)

    belongs_to :role, Role, foreign_key: :role_id

    has_many :posts, Post, on_replace: :nilify
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:login, :email, :password, :role_id])
    |> validate_email(opts)
    |> validate_login(opts)
    |> validate_password(opts)
  end

  def update_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:login, :email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
    |> validate_format(:login, ~r/^[a-zA-Z][^@]*[a-zA-Z][^@]*$/,
      message:
        "must have first alphabetic character no @ sign and at least two alphabetic characters"
    )
    |> validate_length(:login, min: 3)
    |> maybe_validate_unique_login(opts)
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  defp validate_login(changeset, opts) do
    changeset
    |> validate_required([:login])
    |> validate_format(:login, ~r/^[a-zA-Z][^@]*[a-zA-Z][^@]*$/,
      message:
        "must have first alphabetic character no @ sign and at least two alphabetic characters"
    )
    |> validate_length(:login, min: 3)
    |> maybe_validate_unique_login(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, MySuperApp.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_validate_unique_login(changeset, opts) do
    if Keyword.get(opts, :validate_login, true) do
      changeset
      |> unsafe_validate_unique(:login, MySuperApp.Repo)
      |> unique_constraint(:login)
    else
      changeset
    end
  end

  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  def login_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:login])
    |> validate_login(opts)
    |> case do
      %{changes: %{login: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :login, "did not change")
    end
  end

  def role_changeset(user, attrs, opts \\ []) do
    if Keyword.get(opts, :require, true) do
      cast(user, attrs, [:role_id])
      |> validate_required([:role_id])
    else
      cast(user, attrs, [:role_id])
    end
  end

  def avatar_changeset(user, attrs) do
    user
    |> cast(attrs, [:avatar_image])
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  def valid_password?(
        %MySuperApp.User{hashed_password: hashed_password},
        password
      )
      when is_binary(hashed_password) and byte_size(password) > 0 do
        Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end

  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
