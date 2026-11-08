defmodule MySuperAppWeb.UserController do
  @moduledoc false
  use MySuperAppWeb, :controller

  alias MySuperApp.Accounts
  import MySuperAppWeb.ChangesetJSON

  def index(conn, params) when map_size(params) == 0 do
    users = Accounts.get_users()
    render(conn, :index, users: users)
  end

  def index(conn, params) do
    case Accounts.get_users_by_role(params) do
      [_ | _] = users ->
        render(conn, :index, users: users)

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{data: [], message: "No matching records found", status: "not_found"})
    end
  end

  def show(conn, %{"id" => id}) do
    case Accounts.get_user(id) do
      %{} = user ->
        render(conn, :show, user: user)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User with id #{id} not found"})
    end
  end

  def show(conn, %{"name" => name}) do
    case Accounts.get_user_by_name(name) do
      %{} = user ->
        render(conn, :show, user: user)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User with name #{name} not found"})
    end
  end

  def show(conn, %{"email" => email}) do
    case Accounts.get_user_by_email(email) do
      %{} = user ->
        render(conn, :show, user: user)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User with email #{email} not found"})
    end
  end

  def create(conn, %{"user" => user_params}) do
    with true <- check_create_params(user_params),
         {:ok, user} <- Accounts.register_user(user_params) do
      conn
      |> put_status(:created)
      |> render(:show, user: user)
    else
      false ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "You need to specify only these required parameters: email, login, password"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error(%{changeset: changeset})})
    end
  end

  def update(conn, %{"id" => id, "user" => user_params} = params) do
    with %{} = user <- Accounts.get_user(id),
         true <- check_update_params(user_params, params["current_password"]),
         {:ok, updated_user} <-
           Accounts.update_user(user, user_params, params["current_password"]) do
      conn
      |> put_status(:ok)
      |> render(:show, user: Accounts.get_user(updated_user.id))
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User with id #{id} not found"})

      false ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error:
            "You need to provide your current_password, and specify one or many of these parameters: email, login, password"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error(%{changeset: changeset})})
    end
  end

  def delete(conn, %{"id" => id}) do
    with %{} <- Accounts.get_user(id),
         {:ok, _} <- Accounts.delete_user(id) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "There is no User with id #{id}."})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Occurred an error during deletion.", reason: reason})
    end
  end

  defp check_create_params(params) do
    Map.keys(params) |> Enum.sort() == ["email", "login", "password"]
  end

  defp check_update_params(params, current_password) do
    Map.keys(params)
    |> Enum.all?(fn param -> param in ["email", "login", "password"] end) &&
      !is_nil(current_password)
  end
end
