defmodule MySuperAppWeb.UsersSettingsPageTest do
  use MySuperAppWeb.ConnCase

  import MySuperApp.AccountsFixtures

  alias MySuperApp.Accounts

  @password "valid-password-123"
  @image File.read!("test/support/uploads/test_image.jpg")

  setup %{conn: conn} do
    user = user_fixture(%{login: "settings_user"})
    %{conn: log_in_user(conn, user), user: user}
  end

  defp choose_avatar(view) do
    view
    |> file_input("#avatar-form", :avatar, [%{name: "me.png", content: @image, type: "image/png"}])
    |> render_upload("me.png")
  end

  test "requires a logged-in user" do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(build_conn(), ~p"/users/settings")
  end

  test "uploads an avatar to Cloudinary", %{conn: conn, user: user} do
    expect(MySuperApp.CloudinaryMock, :upload, fn _path, opts ->
      assert opts[:folder] == "test/avatars"
      assert opts[:public_id] == "settings_user"

      {:ok,
       %{
         url:
           "https://res.cloudinary.com/test-cloud/image/upload/v2/test/avatars/settings_user.png",
         public_id: "test/avatars/settings_user"
       }}
    end)

    {:ok, view, _html} = live(conn, ~p"/users/settings")
    choose_avatar(view)

    assert view |> form("#avatar-form") |> render_submit() =~ "Avatar updated"
    assert Accounts.get_user(user.id).avatar_image =~ "settings_user.png"
  end

  test "keeps the old avatar when Cloudinary fails", %{conn: conn, user: user} do
    expect(MySuperApp.CloudinaryMock, :upload, fn _path, _opts -> {:error, :timeout} end)
    {:ok, view, _html} = live(conn, ~p"/users/settings")
    choose_avatar(view)

    assert view |> form("#avatar-form") |> render_submit() =~ "Avatar upload failed"
    assert is_nil(Accounts.get_user(user.id).avatar_image)
  end

  test "changes the login with the current password", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    html =
      view
      |> form("#login-form", user: %{login: "renamed_user", current_password: @password})
      |> render_submit()

    assert html =~ "Login updated"
    assert Accounts.get_user(user.id).login == "renamed_user"
  end

  test "rejects a wrong password", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    html =
      view
      |> form("#email-form", user: %{email: "new@example.com", current_password: "nope"})
      |> render_submit()

    refute html =~ "Email updated"
    assert Accounts.get_user(user.id).email == user.email
  end

  test "changes the email with the current password", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    assert view
           |> form("#email-form", user: %{email: "new@example.com", current_password: @password})
           |> render_submit() =~ "Email updated"

    assert Accounts.get_user(user.id).email == "new@example.com"
  end
end
