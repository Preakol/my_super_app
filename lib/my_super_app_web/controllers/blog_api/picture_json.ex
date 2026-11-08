defmodule MySuperAppWeb.PictureJSON do
  @moduledoc false
  alias MySuperApp.Blog.{Picture}

  @doc """
  Renders a list of pictures.
  """
  def index(%{pictures: pictures}) do
    %{data: for(picture <- pictures, do: data(picture))}
  end

  def index(%{paths: pictures}) do
    %{paths: for(picture <- pictures, do: picture.path)}
  end

  @doc """
  Renders a single picture.
  """
  def show(%{picture: picture}) do
    %{data: data(picture)}
  end

  def show(%{path: path}) do
    %{path: path}
  end

  defp data(%Picture{} = picture) do
    %{
      id: picture.id,
      file_name: picture.file_name,
      path: picture.path,
      post_id: picture.post_id,
      upload_at: picture.upload_at
    }
  end
end
