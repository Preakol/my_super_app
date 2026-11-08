defmodule MySuperApp.Cloudinary.Client do
  @moduledoc """
  Minimal Cloudinary Upload API client built on `Req`.

  Only the two calls the app needs are implemented: signed upload and destroy.
  See https://cloudinary.com/documentation/image_upload_api_reference.
  """

  @behaviour MySuperApp.Cloudinary

  @signed_upload_params [:folder, :format, :public_id]

  @impl true
  def upload(path, opts) do
    with {:ok, config} <- fetch_config() do
      params =
        opts
        |> Keyword.take(@signed_upload_params)
        |> Map.new()
        |> Map.put(:timestamp, System.os_time(:second))

      fields =
        params
        |> Map.merge(%{api_key: config.api_key, signature: signature(params, config.secret)})
        |> Enum.map(fn {key, value} -> {key, to_string(value)} end)

      config
      |> request("image/upload", form_multipart: [{:file, File.stream!(path)} | fields])
      |> case do
        {:ok, %{"secure_url" => url, "public_id" => public_id}} ->
          {:ok, %{url: url, public_id: public_id}}

        {:ok, body} ->
          {:error, {:unexpected_response, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def delete(public_id) do
    with {:ok, config} <- fetch_config() do
      params = %{public_id: public_id, timestamp: System.os_time(:second)}

      fields =
        Map.merge(params, %{api_key: config.api_key, signature: signature(params, config.secret)})

      case request(config, "image/destroy", form: fields) do
        {:ok, %{"result" => "ok"}} -> :ok
        {:ok, %{"result" => "not found"}} -> {:error, :not_found}
        {:ok, body} -> {:error, {:unexpected_response, body}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Signs request parameters the way Cloudinary expects: parameters sorted by
  name, joined as `key=value&...`, the API secret appended, SHA-1 hex digest.

      iex> MySuperApp.Cloudinary.Client.signature(%{public_id: "sample_image", timestamp: 1_315_060_510, eager: "w_400,h_300,c_pad|w_260,h_200,c_crop"}, "abcd")
      "bfd09f95f331f558cbd1320e67aa8d488770583e"
  """
  @spec signature(map(), String.t()) :: String.t()
  def signature(params, secret) do
    to_sign =
      params
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map_join("&", fn {key, value} -> "#{key}=#{value}" end)

    :crypto.hash(:sha, to_sign <> secret) |> Base.encode16(case: :lower)
  end

  defp request(config, path, body_opts) do
    [
      method: :post,
      url: "https://api.cloudinary.com/v1_1/#{config.cloud_name}/#{path}",
      retry: false
    ]
    |> Keyword.merge(body_opts)
    |> Keyword.merge(Application.get_env(:my_super_app, :cloudinary_req_options, []))
    |> Req.request()
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp fetch_config do
    config = Application.get_env(:my_super_app, __MODULE__, [])

    case Enum.filter([:api_key, :secret, :cloud_name], &(config[&1] in [nil, ""])) do
      [] -> {:ok, Map.new(config)}
      missing -> {:error, {:not_configured, missing}}
    end
  end
end
