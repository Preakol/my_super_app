defmodule MySuperApp.Cloudinary do
  @moduledoc """
  Image storage on Cloudinary.

  Calls are dispatched to the module configured under
  `config :my_super_app, :cloudinary_client` — `MySuperApp.Cloudinary.Client`
  by default and a Mox mock in tests, so no test talks to the network.
  """

  @type upload_result :: %{url: String.t(), public_id: String.t()}

  @callback upload(path :: Path.t(), opts :: keyword()) ::
              {:ok, upload_result()} | {:error, term()}
  @callback delete(public_id :: String.t()) :: :ok | {:error, term()}

  @spec upload(Path.t(), keyword()) :: {:ok, upload_result()} | {:error, term()}
  def upload(path, opts), do: impl().upload(path, opts)

  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(public_id), do: impl().delete(public_id)

  @doc "Folder prefix that separates uploads of different environments in one cloud."
  @spec folder(String.t()) :: String.t()
  def folder(subfolder),
    do: "#{Application.fetch_env!(:my_super_app, :cloudinary_folder)}/#{subfolder}"

  @doc """
  Extracts the public id (`<env>/<folder>/<name>`) from a delivery URL.

      iex> MySuperApp.Cloudinary.public_id_from_url("https://res.cloudinary.com/demo/image/upload/v1/test/posts/pictures/ab12/cat.jpg")
      {:ok, "test/posts/pictures/ab12/cat"}

      iex> MySuperApp.Cloudinary.public_id_from_url("https://example.com/cat.jpg")
      :error
  """
  @spec public_id_from_url(String.t()) :: {:ok, String.t()} | :error
  def public_id_from_url(url) do
    prefix = Regex.escape(Application.fetch_env!(:my_super_app, :cloudinary_folder))

    case Regex.run(~r{/(#{prefix}/[^.]+)}, url, capture: :all_but_first) do
      [public_id] -> {:ok, public_id}
      nil -> :error
    end
  end

  defp impl, do: Application.fetch_env!(:my_super_app, :cloudinary_client)
end
