defmodule MySuperApp.SortDirection do
  @moduledoc """
  Maps the "ASC"/"DESC" strings the admin pages pass to the contexts onto
  Ecto directions without creating atoms from strings.
  """

  @doc """
      iex> MySuperApp.SortDirection.parse!("DESC")
      :desc

      iex> MySuperApp.SortDirection.parse!("asc")
      :asc
  """
  def parse!(direction) when is_binary(direction) do
    case String.downcase(direction) do
      "asc" -> :asc
      "desc" -> :desc
      _other -> raise ArgumentError, "unknown sort direction: #{inspect(direction)}"
    end
  end
end
