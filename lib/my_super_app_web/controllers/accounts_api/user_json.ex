defmodule MySuperAppWeb.UserJSON do
  @moduledoc false

  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  def show(%{user: user}) do
    %{data: data(user)}
  end

  defp data(%{role_name: role_name} = user) when is_binary(role_name) do
    %{
      id: user.id,
      login: user.login,
      email: user.email,
      role: role_name,
      inserted_at: user.inserted_at
    }
  end

  defp data(user) do
    %{
      id: user.id,
      login: user.login,
      email: user.email,
      inserted_at: user.inserted_at
    }
  end
end
