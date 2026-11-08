defmodule MySuperAppWeb.SiteConfigControllerTest do
  use MySuperAppWeb.ConnCase

  setup :authorize_api

  alias MySuperApp.{SiteConfigManagement, Repo, SiteConfig, Operator}

  @operator_attrs %{name: "John Doe"}
  @valid_site_config_attrs %{brand: "Test Brand", status: true}
  @invalid_site_config_attrs %{brand: nil, status: nil, operator_id: nil}
  @update_site_config_attrs %{status: "STOPPED"}

  setup do
    {:ok, operator} = Operator.changeset(%Operator{}, @operator_attrs) |> Repo.insert()
    %{operator: operator}
  end

  describe "index/2" do
    test "lists all site configs", %{conn: conn, operator: operator} do
      SiteConfigManagement.create_site_config(
        Map.put(@valid_site_config_attrs, :operator_id, operator.id)
      )

      conn = get(conn, ~p"/api/configs")
      assert json_response(conn, 200)["data"] != []
    end

    test "returns site configs filtered by date", %{conn: conn, operator: operator} do
      {:ok, site_config} =
        SiteConfigManagement.create_site_config(
          Map.put(@valid_site_config_attrs, :operator_id, operator.id)
        )

      conn = get(conn, ~p"/api/configs", date: "#{DateTime.to_date(site_config.inserted_at)}")
      assert json_response(conn, 200)["data"] != []
    end

    test "returns not found when no site configs match the date", %{conn: conn} do
      conn = get(conn, ~p"/api/configs", date: "2030-01-01")
      assert json_response(conn, 404)["message"] == "No matching records found"
    end

    test "returns site configs filtered by operator_name", %{conn: conn, operator: operator} do
      {:ok, _site_config} =
        SiteConfigManagement.create_site_config(
          Map.put(@valid_site_config_attrs, :operator_id, operator.id)
        )

      conn = get(conn, ~p"/api/configs", operator_name: operator.name)
      assert json_response(conn, 200)["data"] != []
    end

    test "returns not found when no site configs match operator_name", %{conn: conn} do
      conn = get(conn, ~p"/api/configs", operator_name: "Unknown Operator")
      assert json_response(conn, 404)["message"] == "No matching records found"
    end
  end

  describe "show/2" do
    test "shows a site config by id", %{conn: conn, operator: operator} do
      {:ok, site_config} =
        SiteConfigManagement.create_site_config(
          Map.put(@valid_site_config_attrs, :operator_id, operator.id)
        )

      conn = get(conn, ~p"/api/configs/#{site_config.id}")
      assert json_response(conn, 200)["data"]["id"] == site_config.id
    end

    test "returns 404 when site config id is not found", %{conn: conn} do
      conn = get(conn, ~p"/api/configs/-1")
      assert json_response(conn, 404)["error"] == "Site Config with id -1 not found"
    end
  end

  describe "create/2" do
    test "creates a new site config", %{conn: conn, operator: operator} do
      conn =
        post(conn, ~p"/api/configs",
          site_config: Map.put(@valid_site_config_attrs, :operator_id, operator.id)
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      site_config = Repo.get(SiteConfig, id)
      assert site_config.brand == "Test Brand"
      assert site_config.status == true
    end

    test "returns error when invalid params are provided", %{conn: conn} do
      conn = post(conn, ~p"/api/configs", site_config: @invalid_site_config_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update/2" do
    setup %{operator: operator} do
      {:ok, site_config} =
        SiteConfigManagement.create_site_config(
          Map.put(@valid_site_config_attrs, :operator_id, operator.id)
        )

      %{site_config: site_config}
    end

    test "updates a site config", %{conn: conn, site_config: site_config} do
      conn = put(conn, ~p"/api/configs/#{site_config.id}", site_config: @update_site_config_attrs)
      site_config_id = site_config.id
      assert %{"id" => ^site_config_id} = json_response(conn, 200)["data"]

      updated_site_config = Repo.get(SiteConfig, site_config.id)
      assert updated_site_config.status == false
    end

    test "returns 404 when site config id is not found", %{conn: conn} do
      conn = put(conn, ~p"/api/configs/-1", site_config: @update_site_config_attrs)
      assert json_response(conn, 404)["error"] == "Site Config with id -1 not found"
    end

    test "returns error when params are invalid", %{conn: conn, site_config: site_config} do
      conn = put(conn, ~p"/api/configs/#{site_config.id}", site_config: %{status: "not status"})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete/2" do
    setup %{operator: operator} do
      {:ok, site_config} =
        SiteConfigManagement.create_site_config(
          Map.put(@valid_site_config_attrs, :operator_id, operator.id)
        )

      %{site_config: site_config}
    end

    test "deletes a site config", %{conn: conn, site_config: site_config} do
      conn = delete(conn, ~p"/api/configs/#{site_config.id}")
      assert response(conn, 204)
      refute Repo.get(SiteConfig, site_config.id)
    end

    test "returns 404 when site config id is not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/configs/-1")
      assert json_response(conn, 404)["error"] == "There is no Site Config with id -1."
    end
  end
end
