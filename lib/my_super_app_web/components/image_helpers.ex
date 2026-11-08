defmodule MySuperAppWeb.ImageHelpers do
  @moduledoc false

  alias MySuperApp.Cloudinary

  def get_filename_and_format(file) do
    {Path.rootname(file), file |> String.split(".") |> List.last()}
  end

  def get_picture_attrs(%{url: url}, post_id) do
    %{
      "file_name" => Path.basename(url),
      "path" => url,
      "post_id" => if(post_id == "", do: nil, else: post_id)
    }
  end

  def upload_picture_to_cloud({filename, format}, path) do
    Cloudinary.upload(path,
      folder: Cloudinary.folder("posts/pictures"),
      public_id: "#{Pbkdf2.Tools.get_random_string(7)}/#{filename}",
      format: format
    )
  end

  @doc """
  Removes the picture's file from Cloudinary. A picture without a stored
  path (or with a path that isn't ours) has nothing to remove.
  """
  def delete_picture_from_cloud(nil), do: :ok

  def delete_picture_from_cloud(picture) do
    case Cloudinary.public_id_from_url(picture.path) do
      {:ok, public_id} -> Cloudinary.delete(public_id)
      :error -> :ok
    end
  end
end
