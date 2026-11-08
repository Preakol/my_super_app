defmodule MySuperAppWeb.Plugs.RequireApiToken do
  @moduledoc """
  Lets a request through only with `Authorization: Bearer <token>`, where the
  token is the `API_TOKEN` setting. When no token is configured every
  request is rejected, so a missing setting never opens the write API.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    with expected when is_binary(expected) and expected != "" <-
           Application.get_env(:my_super_app, :api_token),
         ["Bearer " <> given] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(given, expected) do
      conn
    else
      _unauthorized ->
        conn
        |> put_resp_header("www-authenticate", "Bearer")
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()
    end
  end
end
