defmodule MySuperAppWeb.AuthUsersPageTest do
  use MySuperAppWeb.ConnCase, async: true

  import MySuperApp.AccountsFixtures

  setup do
    for login <- ~w(anna anton boris clara dmitry egor fedor) do
      user_fixture(%{login: login, email: "#{login}@example.com"})
    end

    :ok
  end

  defp logins(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("#users tbody tr td:first-child")
    |> Enum.map(&String.trim(Floki.text(&1)))
  end

  test "shows the first page of users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users")

    assert length(logins(view)) == 5
  end

  test "filters by login prefix, case-insensitively", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users")

    view |> form("form[phx-change=change_filter]", filter: "AN") |> render_change()

    assert logins(view) |> Enum.sort() == ~w(anna anton)
  end

  test "sorting by login keeps the filter and toggles direction", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users")
    view |> form("form[phx-change=change_filter]", filter: "an") |> render_change()

    view |> element("#users th button", "Login") |> render_click()
    assert logins(view) == ~w(anna anton)

    view |> element("#users th button", "Login") |> render_click()
    assert logins(view) == ~w(anton anna)
  end

  test "pages through results and changes page size", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users")
    view |> element("#users th button", "Login") |> render_click()

    view |> element("nav[aria-label=Pagination] button", ~r/^\s*2\s*$/) |> render_click()
    assert logins(view) == ~w(egor fedor)

    view |> form("form[phx-change=change_page_size]", value: "10") |> render_change()
    assert length(logins(view)) == 7
  end
end
