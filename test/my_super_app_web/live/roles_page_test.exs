defmodule MySuperAppWeb.RolesPageTest do
  use MySuperAppWeb.ConnCase

  alias MySuperApp.{Operator, Repo, Role}

  setup context do
    operator = Repo.insert!(%Operator{name: "Casino Royale"})
    role = Repo.insert!(%Role{name: "Support", permissions: 3, operator_id: operator.id})
    head = Repo.insert!(%Role{name: "Head", permissions: 2, operator_id: operator.id})

    context |> log_in_admin(1) |> Map.merge(%{operator: operator, role: role, head: head})
  end

  test "lists roles and filters by operator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/roles")
    assert has_element?(view, "#roles td", "Support")

    view
    |> form("form[phx-change=change_operator_filter]", operator: "Casino Royale")
    |> render_change()

    assert has_element?(view, "#roles td", "Support")
    refute has_element?(view, "#roles td", "Role 1")
  end

  test "operator main admin roles cannot be edited", %{conn: conn, head: head, role: role} do
    {:ok, view, _html} = live(conn, ~p"/admin/roles")

    assert has_element?(view, ~s(button[aria-label="Edit #{role.name}"]))
    refute has_element?(view, ~s(button[aria-label="Edit #{head.name}"]))
  end

  test "creates a role", %{conn: conn, operator: operator} do
    {:ok, view, _html} = live(conn, ~p"/admin/roles")
    view |> element("button", "Add new role") |> render_click()

    attrs = %{operator_id: operator.id, name: "Cashier", permissions: 4}
    view |> form("#create-role-form", role: attrs) |> render_change()

    assert view |> form("#create-role-form", role: attrs) |> render_submit() =~ "Role created"
    assert Repo.get_by(Role, name: "Cashier", operator_id: operator.id).permissions == 4
  end

  test "operator admins create roles for their own operator", %{conn: conn} do
    %{conn: conn, user: admin} = log_in_admin(%{conn: conn}, 2)
    operator_id = Repo.preload(admin, :role).role.operator_id
    {:ok, view, _html} = live(conn, ~p"/admin/roles")

    view |> element("button", "Add new role") |> render_click()

    assert view
           |> form("#create-role-form", role: %{name: "Auditor", permissions: 4})
           |> render_submit() =~ "Role created"

    assert Repo.get_by(Role, name: "Auditor").operator_id == operator_id
  end

  test "updates and deletes a role", %{conn: conn, role: role} do
    {:ok, view, _html} = live(conn, ~p"/admin/roles")

    view |> element(~s(button[aria-label="Edit Support"])) |> render_click()

    assert view |> form("#edit-role-form", role: %{name: "Helpdesk"}) |> render_submit() =~
             "Role updated"

    assert Repo.get(Role, role.id).name == "Helpdesk"

    view |> element(~s(button[aria-label="Edit Helpdesk"])) |> render_click()
    view |> element("#edit-role-modal button", "Delete") |> render_click()
    assert view |> element("#delete-role-modal-confirm") |> render_click() =~ "Role deleted"
    refute Repo.get(Role, role.id)
  end

  test "shows validation errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/roles")
    view |> element(~s(button[aria-label="Edit Support"])) |> render_click()

    assert view |> form("#edit-role-form", role: %{name: "@"}) |> render_change() =~
             "must have first alphabetic character"
  end
end
