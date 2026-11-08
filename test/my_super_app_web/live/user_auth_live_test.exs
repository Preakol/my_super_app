defmodule MySuperAppWeb.UserAuthLiveTest do
  use MySuperAppWeb.ConnCase, async: true

  import MySuperApp.AccountsFixtures

  alias MySuperApp.Accounts

  describe "registration" do
    test "creates an account and logs the user in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      attrs = %{login: "newcomer", email: "newcomer@example.com", password: "valid-password-123"}
      form = form(view, "#registration_form", user: attrs)
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_user_by_email("newcomer@example.com")
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      html = view |> form("#registration_form", user: %{email: "not-an-email"}) |> render_change()
      assert html =~ "must have the @ sign and no spaces"
    end
  end

  describe "log in and out" do
    setup do
      %{user: user_fixture(%{login: "returning"})}
    end

    test "logs in with login or email", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/log_in")
      assert html =~ "Email or Login"

      conn =
        post(conn, ~p"/users/log_in", user: %{email: "returning", password: "valid-password-123"})

      assert get_session(conn, :user_token)
    end

    test "rejects a wrong password", %{conn: conn} do
      conn = post(conn, ~p"/users/log_in", user: %{email: "returning", password: "wrong"})
      refute get_session(conn, :user_token)
    end

    test "logs out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end

    test "logged-in users are redirected away from the log in page", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/")

      assert {:error, {:redirect, _}} = live(conn, ~p"/users/log_in")
    end

    test "logged-in users without a stored last path are sent home", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/users/log_in")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "permission redirects" do
    test "go back to the previous page", %{conn: conn} do
      %{conn: conn} = log_in_admin(%{conn: conn}, 3)
      conn = conn |> get(~p"/admin/users") |> recycle() |> get(~p"/admin/operators")

      assert redirected_to(conn) == ~p"/admin/users"
    end

    test "fall back to the home page when the previous page is the forbidden one", %{conn: conn} do
      %{conn: conn} = log_in_admin(%{conn: conn}, 3)
      conn = conn |> get(~p"/admin/operators") |> recycle() |> get(~p"/admin/operators")

      assert redirected_to(conn) == ~p"/"
    end
  end
end
