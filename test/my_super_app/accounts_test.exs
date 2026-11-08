defmodule MySuperApp.AccountsTest do
  use MySuperApp.DataCase

  alias MySuperApp.{Accounts, User, Repo, UserToken, Authority, Operator}

  setup do
    {:ok, operator} = Repo.insert(%Operator{name: "testoperator"})

    {:ok, role} =
      Authority.create_role(%{name: "AdminTest", permissions: 2, operator_id: operator.id})

    {:ok, user} =
      Accounts.register_user(%{
        login: "testadmin",
        email: "test@admin.com",
        password: "password123",
        role_id: role.id
      })

    {:ok, user_without_role} =
      Accounts.register_user(%{
        login: "testuser",
        email: "test@user.com",
        password: "password123"
      })

    %{user: user, role: role, user_without_role: user_without_role}
  end

  describe "register_user/1" do
    test "creates a new user" do
      user_attrs = %{login: "newuser", email: "newuser@example.com", password: "newpassword123"}
      assert {:ok, %User{}} = Accounts.register_user(user_attrs)
    end
  end

  describe "get_user/1" do
    test "returns the user by ID", %{user: user} do
      user_id = user.id
      assert %User{id: ^user_id} = Accounts.get_user(user.id)
    end

    test "returns nil for nonexistent user" do
      assert Accounts.get_user(-1) == nil
    end
  end

  describe "get_users/0" do
    test "returns all users", %{user: user1, user_without_role: user2} do
      user1_id = user1.id
      user2_id = user2.id
      assert [%{id: ^user1_id} | [%{id: ^user2_id} | _]] = Accounts.get_users()
    end
  end

  describe "get_users_by_filters/1" do
    test "returns users matching search criteria", %{user: user} do
      filters = %{search: "testadmin", operator: nil, role: nil, sorting: [id: "ASC"]}
      user_id = user.id
      assert [%{id: ^user_id}] = Accounts.get_users_by_filters(filters)
    end

    test "returns users matching operator criteria", %{user: user} do
      user = Accounts.get_user_with_op_and_role(user.id)
      filters = %{search: "", operator: user.operator_name, role: nil, sorting: [id: "ASC"]}
      user_id = user.id
      assert [%{id: ^user_id}] = Accounts.get_users_by_filters(filters)
    end

    test "returns users matching role criteria", %{user: user} do
      user = Accounts.get_user_with_op_and_role(user.id)

      filters = %{
        search: "",
        operator: user.operator_name,
        role: user.role_name,
        sorting: [id: "ASC"]
      }

      user_id = user.id
      assert [%{id: ^user_id}] = Accounts.get_users_by_filters(filters)
    end

    test "returns empty list when no users match" do
      filters = %{search: "nonexistent", operator: nil, role: nil, sorting: [id: "ASC"]}
      assert Accounts.get_users_by_filters(filters) == []
    end
  end

  describe "get_users_without_role/0" do
    test "returns users without roles", %{user_without_role: user} do
      user_id = user.id
      assert [%User{id: ^user_id} | _] = Accounts.get_users_without_role()
    end
  end

  describe "get_users_by_role/1" do
    test "returns users by role name", %{role: role} do
      role_name = role.name

      assert [%{role_name: ^role_name} | _] =
               Accounts.get_users_by_role(%{"role_name" => role_name})
    end

    test "returns users by role ID", %{role: role} do
      role_id = role.id
      assert [%{role_id: ^role_id} | _] = Accounts.get_users_by_role(%{"role_id" => role_id})
    end

    test "returns empty list for unknown role" do
      assert Accounts.get_users_by_role(%{"role_name" => "unknown"}) == []
    end
  end

  describe "delete_user/1" do
    test "deletes the user", %{user: user} do
      assert {:ok, %User{}} = Accounts.delete_user(user.id)
      assert Accounts.get_user(user.id) == nil
    end
  end

  describe "update_user/3" do
    test "updates user information", %{user: user} do
      attrs = %{email: "new_email@example.com"}

      assert {:ok, %User{email: "new_email@example.com"}} =
               Accounts.update_user(user, attrs, "password123")
    end

    test "returns error for invalid password", %{user: user} do
      attrs = %{email: "new_email@example.com"}
      assert {:error, _changeset} = Accounts.update_user(user, attrs, "wrongpassword")
    end
  end

  describe "update_user_role/2" do
    test "updates user role", %{user: user, role: role} do
      role_id = role.id
      assert {:ok, %User{role_id: ^role_id}} = Accounts.update_user_role(user.id, role.id)
    end
  end

  describe "remove_user_role/1" do
    test "removes user role", %{user: user} do
      assert {:ok, %User{role_id: nil}} = Accounts.remove_user_role(user.id)
    end
  end

  describe "update_user_avatar/2" do
    test "updates the avatar image", %{user: user} do
      assert {:ok, %User{avatar_image: "new_avatar.png"}} =
               Accounts.update_user_avatar(user.id, "new_avatar.png")
    end
  end

  describe "get_user_by_email/1" do
    test "returns user by email", %{user: user} do
      user_id = user.id
      assert %{id: ^user_id} = Accounts.get_user_by_email(user.email)
    end

    test "returns nil for nonexistent email" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "get_user_by_name/1" do
    test "returns user by login name", %{user: user} do
      user_id = user.id
      assert %{id: ^user_id} = Accounts.get_user_by_name(user.login)
    end

    test "returns nil for nonexistent name" do
      assert Accounts.get_user_by_name("nonexistent_user") == nil
    end
  end

  describe "get_user_by_email_or_login_and_password/2" do
    test "returns user with valid email and password", %{user: user} do
      user_id = user.id

      assert %User{id: ^user_id} =
               Accounts.get_user_by_email_or_login_and_password(user.email, "password123")
    end

    test "returns user with valid login and password", %{user: user} do
      user_id = user.id

      assert %User{id: ^user_id} =
               Accounts.get_user_by_email_or_login_and_password(user.login, "password123")
    end

    test "returns nil for invalid credentials" do
      assert Accounts.get_user_by_email_or_login_and_password("wrong", "wrong") == nil
    end
  end

  describe "generate_user_session_token/1" do
    test "generates a session token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)
      assert Repo.get_by(UserToken, token: token)
    end
  end

  describe "get_user_by_session_token/1" do
    test "retrieves user by session token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      user_id = user.id
      assert %{id: ^user_id} = Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the session token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert :ok = Accounts.delete_user_session_token(token)
      assert Repo.get_by(UserToken, token: token) == nil
    end
  end

  describe "change_user_registration/2" do
    test "returns valid changeset" do
      user_attrs = %{login: "newtestuser", email: "newtest@example.com", password: "password123"}
      changeset = Accounts.change_user_registration(%User{}, user_attrs)
      assert changeset.valid?
    end
  end

  describe "change_user_email/1" do
    test "returns valid changeset" do
      changeset = Accounts.change_user_email(%{email: "new_email@example.com"})
      assert changeset.valid?
    end
  end

  describe "change_user_login/1" do
    test "returns valid changeset" do
      changeset = Accounts.change_user_login(%{login: "newlogin"})
      assert changeset.valid?
    end
  end

  describe "apply_user_email/3" do
    test "applies user email changes with valid password", %{user: user} do
      assert {:ok, %User{email: "new_email@example.com"}} =
               Accounts.apply_user_email(user, "password123", %{email: "new_email@example.com"})
    end

    test "returns error for invalid password", %{user: user} do
      assert {:error, _changeset} =
               Accounts.apply_user_email(user, "wrongpassword", %{email: "new_email@example.com"})
    end
  end

  describe "apply_user_login/3" do
    test "applies user login changes with valid password", %{user: user} do
      assert {:ok, %User{login: "newlogin"}} =
               Accounts.apply_user_login(user, "password123", %{login: "newlogin"})
    end

    test "returns error for invalid password", %{user: user} do
      assert {:error, _changeset} =
               Accounts.apply_user_login(user, "wrongpassword", %{login: "newlogin"})
    end
  end
end
