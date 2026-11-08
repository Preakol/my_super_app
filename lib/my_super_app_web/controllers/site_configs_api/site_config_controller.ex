defmodule MySuperAppWeb.SiteConfigController do
  @moduledoc false

  use MySuperAppWeb, :controller

  alias MySuperApp.{SiteConfigManagement, SiteConfig}
  import MySuperAppWeb.ChangesetJSON

  def index(conn, params) when map_size(params) == 0 do
    site_configs = SiteConfigManagement.list_site_configs()
    render(conn, :index, site_configs: site_configs)
  end

  def index(conn, %{"date" => date}) do
    case SiteConfigManagement.list_site_configs_by_date(date) do
      [_ | _] = site_configs ->
        render(conn, :index, site_configs: site_configs)

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{data: [], message: "No matching records found", status: "not_found"})
    end
  end

  def index(conn, %{"operator_name" => operator_name}) do
    case SiteConfigManagement.list_site_configs_by_op(operator_name) do
      [_ | _] = site_configs ->
        render(conn, :index, site_configs: site_configs)

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{data: [], message: "No matching records found", status: "not_found"})
    end
  end

  def show(conn, %{"id" => id}) do
    case SiteConfigManagement.get_site_config(id) do
      %SiteConfig{} = site_config ->
        render(conn, :show, site_config: site_config)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Site Config with id #{id} not found"})
    end
  end

  def create(conn, %{"site_config" => params}) do
    case SiteConfigManagement.create_site_config(params) do
      {:ok, site_config} ->
        conn
        |> put_status(:created)
        |> render(:show, site_config: site_config)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error(%{changeset: changeset})})
    end
  end

  def update(conn, %{"id" => id, "site_config" => %{"status" => status}}) do
    with %SiteConfig{} <- SiteConfigManagement.get_site_config(id), true <- check_status_param(status),
     {:ok, updated_config} <- SiteConfigManagement.update_site_config(id, %{status: status == "ACTIVE"}) do
      conn
      |> put_status(:ok)
      |> render(:show, site_config: updated_config)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Site Config with id #{id} not found"})

      false ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Status can be set either to STOPPED or ACTIVE"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error(%{changeset: changeset})})
    end
  end

  def delete(conn, %{"id" => id}) do
    with %SiteConfig{} <- SiteConfigManagement.get_site_config(id),
         {:ok, _} <- SiteConfigManagement.delete_site_config(id) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no Site Config with id #{id}."})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Occurred an error during deletion.", reason: reason})
    end
  end

  defp check_status_param(status) do
    status in ["STOPPED", "ACTIVE"]
  end
end
