defmodule MySuperAppWeb.OperatorsPageTest do
  use MySuperAppWeb.ConnCase

  import MySuperApp.AccountsFixtures

  alias MySuperApp.{Accounts, Operator, Repo}

  setup :super_admin

  defp super_admin(context), do: log_in_admin(context, 1)

  test "creates an operator and makes the chosen user its head", %{conn: conn} do
    head = user_fixture(%{login: "newhead"})
    {:ok, view, _html} = live(conn, ~p"/admin/operators")

    view |> element("button", "Add new operator") |> render_click()
    view |> form("#create-operator-form", operator: %{name: "Lucky Spin"}) |> render_change()

    html =
      view
      |> form("#create-operator-form", operator: %{name: "Lucky Spin", user_id: head.id})
      |> render_submit()

    assert html =~ "Operator created"
    assert has_element?(view, "#operators td", "Lucky Spin")
    assert Accounts.get_user(head.id).role.name == "Head of Lucky Spin"
  end

  test "validates the operator name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/operators")
    view |> element("button", "Add new operator") |> render_click()

    assert view |> form("#create-operator-form", operator: %{name: "ab"}) |> render_change() =~
             "should be at least 3"
  end

  test "deletes an operator after confirmation", %{conn: conn} do
    operator = Repo.insert!(%Operator{name: "Gone Casino"})
    {:ok, view, _html} = live(conn, ~p"/admin/operators")

    view |> element(~s(button[aria-label="Delete Gone Casino"])) |> render_click()

    assert view |> element("#delete-operator-modal-confirm") |> render_click() =~
             "Gone Casino deleted"

    refute Repo.get(Operator, operator.id)
  end

  test "pages and sorts operators", %{conn: conn} do
    for n <- 1..6, do: Repo.insert!(%Operator{name: "Zz #{n}"})
    {:ok, view, _html} = live(conn, ~p"/admin/operators")

    view |> element("#operators th button", "Name") |> render_click()
    view |> element("#operators th button", "Name") |> render_click()
    assert view |> element("#operators tbody tr:first-child") |> render() =~ "Zz 6"

    view |> element("nav[aria-label=Pagination] button", ~r/^\s*2\s*$/) |> render_click()
    assert has_element?(view, "#operators tbody tr")
  end

  test "is not available below super admin", %{conn: conn} do
    %{conn: conn} = log_in_admin(%{conn: conn}, 2)
    assert {:error, {:redirect, _}} = live(conn, ~p"/admin/operators")
  end
end
