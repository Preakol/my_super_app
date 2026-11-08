defmodule MySuperAppWeb.SiteConfigsPageTest do
  use MySuperAppWeb.ConnCase

  alias MySuperApp.{Operator, Repo, SiteConfig}

  setup context do
    operator = Repo.insert!(%Operator{name: "Casino Royale"})
    Repo.insert_all("brands", [[name: "Spinbet"], [name: "Luckybet"], [name: "Jackpotland"]])

    config =
      Repo.insert!(%SiteConfig{
        brand: "Spinbet",
        operator_id: operator.id,
        status: true,
        inserted_at: ~U[2024-03-05 10:00:00Z]
      })

    context |> log_in_admin(1) |> Map.merge(%{operator: operator, config: config})
  end

  test "searches by brand", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/site-configs")
    assert has_element?(view, "#site-configs td", "Spinbet")

    view |> form("form[phx-change=change_search]", search: "lucky") |> render_change()
    refute has_element?(view, "#site-configs td", "Spinbet")
  end

  test "filters by an inclusive date range in either order", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/site-configs")

    view
    |> form("form[phx-change=change_dates]", start_date: "2024-03-10", end_date: "")
    |> render_change()

    assert has_element?(view, "#site-configs td", "Spinbet")

    view
    |> form("form[phx-change=change_dates]", start_date: "2024-03-10", end_date: "2024-03-05")
    |> render_change()

    assert has_element?(view, "#site-configs td", "Spinbet")

    view
    |> form("form[phx-change=change_dates]", start_date: "2024-04-01", end_date: "2024-04-30")
    |> render_change()

    refute has_element?(view, "#site-configs td", "Spinbet")
  end

  test "stops and restarts a site", %{conn: conn, config: config} do
    {:ok, view, _html} = live(conn, ~p"/admin/site-configs")

    view |> element(~s(button[aria-label="Stop Spinbet"])) |> render_click()
    assert has_element?(view, "#site-config-#{config.id}", "STOPPED")
    refute Repo.get(SiteConfig, config.id).status

    view |> element(~s(button[aria-label="Start Spinbet"])) |> render_click()
    assert Repo.get(SiteConfig, config.id).status
  end

  test "creates a config; brands already in use are disabled", %{conn: conn, operator: operator} do
    {:ok, view, _html} = live(conn, ~p"/admin/site-configs")
    view |> element("button", "Add site config") |> render_click()

    view
    |> form("#create-config-form", site_config: %{operator_id: operator.id})
    |> render_change()

    assert has_element?(view, ~s(#create-config-form option[value="Spinbet"][disabled]))

    html =
      view
      |> form("#create-config-form", site_config: %{operator_id: operator.id, brand: "Luckybet"})
      |> render_submit()

    assert html =~ "Site config for Luckybet created"
    assert Repo.get_by(SiteConfig, brand: "Luckybet")
  end

  test "deletes a config", %{conn: conn, config: config} do
    {:ok, view, _html} = live(conn, ~p"/admin/site-configs")

    view |> element(~s(button[aria-label="Delete Spinbet"])) |> render_click()

    assert view |> element("#delete-config-modal-confirm") |> render_click() =~
             "Site config for Spinbet deleted"

    refute Repo.get(SiteConfig, config.id)
  end
end
