defmodule MySuperAppWeb.AdminWelcomeTest do
  use MySuperAppWeb.ConnCase, async: true

  import MySuperApp.AccountsFixtures

  defp section_links(view) do
    for section <- ["Users", "Posts", "Pictures", "Operators", "Roles", "Site Configs"],
        has_element?(view, "main a", section),
        do: section
  end

  test "super admins see every section", %{conn: conn} do
    {:ok, view, html} =
      conn |> log_in_user(admin_fixture(1, %{login: "boss"})) |> live(~p"/admin")

    assert html =~ "Welcome to the admin area, boss"

    assert section_links(view) == [
             "Users",
             "Posts",
             "Pictures",
             "Operators",
             "Roles",
             "Site Configs"
           ]
  end

  test "operator admins cannot manage operators", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_user(admin_fixture(2)) |> live(~p"/admin")

    assert section_links(view) == ["Users", "Posts", "Pictures", "Roles", "Site Configs"]
  end

  test "operator staff only see content sections", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_user(admin_fixture(3)) |> live(~p"/admin")

    assert section_links(view) == ["Users", "Posts", "Pictures"]
  end

  test "users without a role are redirected away", %{conn: conn} do
    assert {:error, {:redirect, _}} = conn |> log_in_user(user_fixture()) |> live(~p"/admin")
  end
end
