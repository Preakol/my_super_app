defmodule MySuperAppWeb.ImageHelpers do
  @moduledoc false

  @env System.get_env("MIX_ENV")

  def get_filename_and_format(file) do
    filename =
      file
      |> Path.rootname()

    format =
      String.split(file, ".")
      |> Enum.at(-1)

    {filename, format}
  end

  def get_picture_attrs(%Cloudex.UploadedImage{secure_url: url_path}, post_id) do
    %{
      "file_name" => Path.basename(url_path),
      "path" => url_path,
      "post_id" => post_id == "" && nil || post_id
    }
  end

  def upload_picture_to_cloud({filename, format}, path) do
    Cloudex.upload(path, upload_attrs(filename, format))
  end

  def delete_picture_from_cloud(picture) do
    get_picture_path(picture)
    |> extract_public_id()
    |> Cloudex.delete()
  end

  defp get_picture_path(nil), do: ""

  defp get_picture_path(picture), do: picture.path

  defp extract_public_id(url) do
    case Regex.run(~r/#{@env}\/[^.]+/, url) do
      [match] -> match
      _ -> ""
    end
  end

  defp upload_attrs(filename, format) do
    %{folder: "#{@env}/posts/pictures", public_id: "#{Pbkdf2.Tools.get_random_string(7)}/#{filename}", format: format}
  end
end
