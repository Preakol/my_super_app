defmodule MySuperAppWeb.AdminMainPageTest do
  use MySuperAppWeb.ConnCase

  import MySuperApp.AccountsFixtures

  alias MySuperApp.{Accounts, Operator, Repo, Role}
  alias MySuperAppWeb.AdminMainPage

  defp logins(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("#admin-users tbody tr td:nth-child(2)")
    |> Enum.map(&(&1 |> Floki.text() |> String.split() |> List.first()))
  end

  describe "as super admin" do
    setup %{conn: conn} do
      operator = Repo.insert!(%Operator{name: "Casino Royale"})
      role = Repo.insert!(%Role{name: "Support", permissions: 3, operator_id: operator.id})

      staff =
        user_fixture(%{login: "alice"})
        |> Ecto.Changeset.change(role_id: role.id)
        |> Repo.update!()

      newbie = user_fixture(%{login: "bob"})

      %{conn: conn}
      |> log_in_admin(1)
      |> Map.merge(%{operator: operator, role: role, staff: staff, newbie: newbie})
    end

    test "lists users and searches by login", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      assert Enum.sort(logins(view)) == ~w(alice bob)

      view |> form("form[phx-change=change_search]", search: "ali") |> render_change()
      assert logins(view) == ~w(alice)
    end

    test "filters by operator and then by role", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      assert has_element?(view, "#role-filter[disabled]")

      view
      |> form("form[phx-change=change_operator_filter]", operator: "Casino Royale")
      |> render_change()

      refute has_element?(view, "#role-filter[disabled]")
      assert logins(view) == ~w(alice)

      view |> form("form[phx-change=change_role_filter]", role: "Support") |> render_change()
      assert logins(view) == ~w(alice)

      view |> element("button", "Clear filters") |> render_click()
      assert Enum.sort(logins(view)) == ~w(alice bob)
    end

    test "gives a role to a user", %{conn: conn, newbie: newbie, role: role} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view |> element(~s(button[aria-label="Manage role of bob"])) |> render_click()

      view
      |> form("form[phx-change=change_manage_operator]", operator: "Casino Royale")
      |> render_change()

      html = view |> form("#manage-role-form", user: %{role_id: role.id}) |> render_submit()

      assert html =~ "Role updated"
      assert Accounts.get_user(newbie.id).role_id == role.id
      refute has_element?(view, "#manage-modal")
    end

    test "removes a role", %{conn: conn, staff: staff} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view |> element(~s(button[aria-label="Manage role of alice"])) |> render_click()
      assert view |> element("button", "Remove role") |> render_click() =~ "Role removed"
      assert is_nil(Accounts.get_user(staff.id).role_id)
    end

    test "deletes a user after confirmation", %{conn: conn, newbie: newbie} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view |> element(~s(button[aria-label="Delete bob"])) |> render_click()
      assert has_element?(view, "#delete-user-modal", "Delete user bob?")

      assert view |> element("#delete-user-modal-confirm") |> render_click() =~
               "User bob deleted."

      assert is_nil(Accounts.get_user(newbie.id))
      assert logins(view) == ~w(alice)
    end

    test "cancelling the delete dialog keeps the user", %{conn: conn, newbie: newbie} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view |> element(~s(button[aria-label="Delete bob"])) |> render_click()
      view |> element("#delete-user-modal button", "Cancel") |> render_click()

      refute has_element?(view, "#delete-user-modal")
      assert Accounts.get_user(newbie.id)
    end
  end

  test "staff below level 4 see roles but staff at level 4 get a read-only table", %{conn: conn} do
    %{conn: staff_conn} = log_in_admin(%{conn: conn}, 4)
    {:ok, view, _html} = live(staff_conn, ~p"/admin/users")

    refute has_element?(view, "#admin-users th", "Role")
    refute has_element?(view, ~s(#admin-users button[aria-label^="Delete"]))
  end

  describe "permission rules" do
    @super %{id: 1, permissions: 1, operator_id: 10}
    @operator_admin %{id: 2, permissions: 2, operator_id: 10}

    test "super admins may delete anyone except operator main admins" do
      assert AdminMainPage.can_delete?(@super, %{
               id: 5,
               permissions: 3,
               operator_id: 99,
               role_id: 1
             })

      refute AdminMainPage.can_delete?(@super, %{
               id: 5,
               permissions: 2,
               operator_id: 99,
               role_id: 1
             })
    end

    test "operator admins may delete lower roles of their operator and users without a role" do
      assert AdminMainPage.can_delete?(@operator_admin, %{
               id: 5,
               permissions: 3,
               operator_id: 10,
               role_id: 1
             })

      assert AdminMainPage.can_delete?(@operator_admin, %{
               id: 5,
               permissions: nil,
               operator_id: nil,
               role_id: nil
             })

      refute AdminMainPage.can_delete?(@operator_admin, %{
               id: 5,
               permissions: 3,
               operator_id: 99,
               role_id: 1
             })

      refute AdminMainPage.can_delete?(@operator_admin, @operator_admin)
    end

    test "nobody may manage their own role" do
      refute AdminMainPage.can_manage?(@super, @super)
      refute AdminMainPage.can_manage?(@operator_admin, @operator_admin)
    end

    test "super admins may manage any other user" do
      assert AdminMainPage.can_manage?(@super, %{
               id: 5,
               permissions: 2,
               operator_id: 99,
               role_id: 1
             })
    end

    test "operator admins may manage lower roles of their operator and users without a role" do
      assert AdminMainPage.can_manage?(@operator_admin, %{
               id: 5,
               permissions: 3,
               operator_id: 10,
               role_id: 1
             })

      assert AdminMainPage.can_manage?(@operator_admin, %{
               id: 5,
               permissions: nil,
               operator_id: nil,
               role_id: nil
             })

      refute AdminMainPage.can_manage?(@operator_admin, %{
               id: 5,
               permissions: 3,
               operator_id: 99,
               role_id: 1
             })

      refute AdminMainPage.can_manage?(@operator_admin, %{
               id: 5,
               permissions: 2,
               operator_id: 10,
               role_id: 1
             })
    end
  end

  describe "server-side role checks" do
    setup %{conn: conn} do
      %{conn: admin_conn, user: admin} = log_in_admin(%{conn: conn}, 2)
      other_operator = Repo.insert!(%Operator{name: "Other casino"})

      foreign_role =
        Repo.insert!(%Role{name: "Foreign", permissions: 3, operator_id: other_operator.id})

      %{conn: admin_conn, admin: admin, foreign_role: foreign_role}
    end

    test "the manage button is not shown for the current user", %{conn: conn, admin: admin} do
      newbie = user_fixture(%{login: "newbie"})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, ~s(button[aria-label="Manage role of #{newbie.login}"]))
      refute has_element?(view, ~s(button[aria-label="Manage role of #{admin.login}"]))
    end

    test "opening the dialog for yourself is rejected", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html = render_hook(view, "open_manage", %{"value" => to_string(admin.id)})

      assert html =~ "You are not allowed to manage this user"
      refute has_element?(view, "#manage-modal")
    end

    test "saving a role the admin cannot grant is rejected", %{
      conn: conn,
      foreign_role: foreign_role
    } do
      newbie = user_fixture(%{login: "newbie"})
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      render_hook(view, "open_manage", %{"value" => to_string(newbie.id)})

      html =
        render_hook(view, "save_role", %{"user" => %{"role_id" => to_string(foreign_role.id)}})

      assert html =~ "This role is not available"
      assert is_nil(Repo.reload!(newbie).role_id)
    end

    test "saving is rejected when the target became unmanageable", %{conn: conn, admin: admin} do
      newbie = user_fixture(%{login: "newbie"})
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      render_hook(view, "open_manage", %{"value" => to_string(newbie.id)})

      higher_role =
        Repo.insert!(%Role{name: "Boss", permissions: 2, operator_id: admin_operator_id(admin)})

      newbie |> Ecto.Changeset.change(role_id: higher_role.id) |> Repo.update!()

      html = render_hook(view, "remove_role", %{})

      assert html =~ "You are not allowed to manage this user"
      assert Repo.reload!(newbie).role_id == higher_role.id
    end
  end

  defp admin_operator_id(admin), do: Repo.get!(Role, admin.role_id).operator_id
end
