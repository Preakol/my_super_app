defmodule MySuperAppWeb.RoleController do
  @moduledoc false

  use MySuperAppWeb, :controller

  alias MySuperApp.{Authority, Role}
  import MySuperAppWeb.ChangesetJSON

  def index(conn, params) when map_size(params) == 0 do
    roles = Authority.get_roles()
    render(conn, :index, roles: roles)
  end

  def index(conn, %{"name" => name, "operator_id" => operator_id}) do
    case Authority.get_role_by_name_and_op_id(name, operator_id) do
      %Role{} = role ->
        render(conn, :show, role: role)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no Role addressing such parameters"})
    end
  end

  def show(conn, %{"id" => id}) do
    case Authority.get_role(id) do
      %Role{} = role ->
        render(conn, :show, role: role)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Role with id #{id} not found"})
    end
  end

  def show(conn, %{"user_id" => user_id}) do
    case Authority.get_role_by_user_id(user_id) do
      %Role{} = role ->
        render(conn, :show, role: role)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Role with user_id #{user_id} not found"})
    end
  end

  def create(conn, %{"role" => params}) do
    with true <- check_permissions_param(params["permissions"]),
         {:ok, role} <- Authority.create_role(params) do
      conn
      |> put_status(:created)
      |> render(:show, role: role)
    else
      false ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "You need to specify \"permissions\", options: 3(Gamechanger), 4(Viewer)."
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error(%{changeset: changeset})})
    end
  end

  def update(conn, %{"id" => id, "role" => params}) do
    with %Role{} <- Authority.get_role(id),
         true <- check_update_params(params),
         {:ok, updated_role} <- Authority.update_role(id, params) do
      conn
      |> put_status(:ok)
      |> render(:show, role: updated_role)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Role with id #{id} not found"})

      false ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error:
            "You can only update the name of the Role and permissions, permissions options: 3(Gamechanger), 4(Viewer)."
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error(%{changeset: changeset})})
    end
  end

  def delete(conn, %{"id" => id}) do
    with %Role{} <- Authority.get_role(id),
         {:ok, _} <- Authority.delete_role(id) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no Role with id #{id}."})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Occurred an error during deletion.", reason: reason})
    end
  end

  defp check_permissions_param(permissions) do
    permissions in [3, 4]
  end

  defp check_update_params(params) do
    if params["permissions"] do
      Map.keys(params)
      |> Enum.all?(fn param -> param in ["permissions", "name"] end) &&
        params["permissions"] in [3, 4]
    else
      Map.keys(params)
      |> Enum.all?(fn param -> param in ["permissions", "name"] end)
    end
  end
end
