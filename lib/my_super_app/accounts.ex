defmodule MySuperApp.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias MySuperApp.{Repo, User, UserToken, AdminPubSub}

  import Ecto.Query, warn: false

  def get_users() do
    user_with_op_and_role_query(User)
    |> Repo.all()
  end

  def get_users_by_filters(%{search: search, operator: operator, role: role, sorting: sorting}) do
    user_with_op_and_role_query(User)
    |> add_search_filter(search)
    |> add_operator_filter(operator)
    |> add_role_filter(role)
    |> add_sorting(sorting)
    |> Repo.all()
  end

  def get_users_without_role() do
    from(user in User, left_join: role in assoc(user, :role), where: is_nil(role))
    |> Repo.all()
  end

  def get_users_by_role(%{"role_name" => role_name}) do
    from(u in User,
      join: r in assoc(u, :role),
      where: r.name == ^role_name
    )
    |> user_with_op_and_role_query()
    |> Repo.all()
  end

  def get_users_by_role(%{"role_id" => role_id}) do
    from(u in User, where: u.role_id == ^role_id)
    |> user_with_op_and_role_query()
    |> Repo.all()
  end

  def get_users_by_role(_), do: []

  def delete_user(id) do
    User
    |> Repo.get(id)
    |> Repo.delete()
    |> AdminPubSub.broadcast()
  end

  def update_user(%User{} = user, attrs, current_password) do
    user
    |> User.update_changeset(attrs)
    |> User.validate_current_password(current_password)
    |> Repo.update()
    |> AdminPubSub.broadcast()
  end

  def update_user_role(user_id, role_id) do
    User
    |> Repo.get(user_id)
    |> User.role_changeset(%{role_id: role_id})
    |> Repo.update()
    |> AdminPubSub.broadcast(:update_role)
  end

  def remove_user_role(user_id) do
    User
    |> Repo.get(user_id)
    |> User.role_changeset(%{role_id: nil}, require: false)
    |> Repo.update()
    |> AdminPubSub.broadcast(:update_role)
  end

  def update_user_avatar(user_id, avatar_image) do
    User
    |> Repo.get(user_id)
    |> User.avatar_changeset(%{avatar_image: avatar_image})
    |> Repo.update()
  end

  def get_user(""), do: nil

  def get_user(id) do
    from(user in User,
      left_join: role in assoc(user, :role),
      left_join: operator in assoc(role, :operator),
      preload: [role: {role, operator: operator}]
    )
    |> Repo.get(id)
  end

  def get_user_with_op_and_role(id) do
    user_with_op_and_role_query(User)
    |> Repo.get(id)
  end

  def get_user_by_name(name) when is_binary(name) do
    user_with_op_and_role_query(User)
    |> Repo.get_by(login: name)
  end

  def get_user_by_email(email) when is_binary(email) do
    user_with_op_and_role_query(User)
    |> Repo.get_by(email: email)
  end

  def get_main_admin_by_operator(nil), do: nil

  def get_main_admin_by_operator(operator_name) do
    from(user in User,
      join: role in assoc(user, :role),
      join: operator in assoc(role, :operator),
      where: role.permissions == 2 and operator.name == ^operator_name
    )
    |> Repo.one()
  end

  def get_user_by_email_or_login_and_password(email_or_login, password)
      when is_binary(email_or_login) and is_binary(password) do
    user =
      Repo.one(
        from u in User,
          where: u.email == ^email_or_login or u.login == ^email_or_login
      )

    if User.valid_password?(user, password), do: user
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> AdminPubSub.broadcast()
  end

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  def change_user_email(attrs \\ %{}) do
    %User{}
    |> User.email_changeset(attrs, validate_email: false)
  end

  def change_user_login(attrs \\ %{}) do
    %User{}
    |> User.login_changeset(attrs, validate_login: false)
  end

  def change_user_role(user, attrs \\ %{}) do
    user
    |> User.role_changeset(attrs)
  end

  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Repo.update()
    |> AdminPubSub.broadcast(:update_email)
  end

  def apply_user_login(user, password, attrs) do
    user
    |> User.login_changeset(attrs)
    |> User.validate_current_password(password)
    |> Repo.update()
    |> AdminPubSub.broadcast()
  end

  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  defp add_search_filter(query, search) do
    case Integer.parse(search) do
      {number, ""} ->
        from(user in query, where: user.id == ^number)

      _ ->
        from(user in query, where: ilike(user.login, ^"#{search}%"))
    end
  end

  defp add_operator_filter(query, operator_name)
       when is_nil(operator_name) or operator_name == "Select Operator", do: query

  defp add_operator_filter(query, operator_name) do
    from(user in query,
      left_join: role in assoc(user, :role),
      left_join: operator in assoc(role, :operator),
      where: operator.name == ^operator_name
    )
  end

  defp add_role_filter(query, role_name) when is_nil(role_name) or role_name == "Select Role",
    do: query

  defp add_role_filter(query, role_name) do
    from(user in query,
      left_join: role in assoc(user, :role),
      where: role.name == ^role_name
    )
  end

  defp add_sorting(query, [{parameter, direction}]) do
    from(user in query,
      order_by: ^[{direction |> String.downcase() |> String.to_atom(), parameter}]
    )
  end

  defp user_with_op_and_role_query(query) do
    from(user in query,
      left_join: role in assoc(user, :role),
      left_join: operator in assoc(role, :operator),
      # role.permissions > 1
      where: is_nil(role.permissions) or role.permissions != 1,
      select: %{
        id: user.id,
        login: user.login,
        email: user.email,
        operator_id: operator.id,
        operator_name: operator.name,
        role_id: role.id,
        role_name: role.name,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at,
        permissions: role.permissions
      }
    )
  end
end
