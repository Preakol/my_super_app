defmodule MySuperApp.CloudinaryStub do
  @moduledoc """
  Default Cloudinary behaviour in tests: "uploads" succeed and return a
  deterministic delivery URL built from the requested folder and public id.
  """

  @behaviour MySuperApp.Cloudinary

  @impl true
  def upload(_path, opts) do
    public_id = Enum.join([opts[:folder], opts[:public_id]], "/")
    extension = opts[:format] || "jpg"

    {:ok,
     %{
       url: "https://res.cloudinary.com/test-cloud/image/upload/v1/#{public_id}.#{extension}",
       public_id: public_id
     }}
  end

  @impl true
  def delete(_public_id), do: :ok
end
