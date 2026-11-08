defmodule MySuperAppWeb.HomeLiveTest do
  use MySuperAppWeb.ConnCase, async: true

  import MySuperApp.AccountsFixtures

  test "guests see log in and register links", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, ~s(main a[href="/users/log_in"]))
    assert has_element?(view, ~s(main a[href="/users/register"]))
    refute has_element?(view, ~s(a[href="/admin"]))
  end

  test "users with an admin role get a link to the admin area", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_user(admin_fixture(3)) |> live(~p"/")

    assert has_element?(view, ~s(main a[href="/admin"]))
    assert has_element?(view, "#user-menu")
  end

  test "users without a role do not see the admin link", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/")

    refute has_element?(view, ~s(main a[href="/admin"]))
    assert has_element?(view, ~s(main a[href="/users/settings"]))
  end
end
