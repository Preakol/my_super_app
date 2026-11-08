defmodule MySuperAppWeb.SortParams do
  @moduledoc """
  Validates the `order_by`/`dir` query parameters of the JSON API against a
  whitelist, so request input is never turned into atoms.
  """

  @directions %{"asc" => :asc, "desc" => :desc}

  @doc """
  Returns `{:ok, sorting}` for the context functions, `{:ok, default}` when
  the parameters are absent, or `{:error, message}` for unknown values.

      iex> MySuperAppWeb.SortParams.parse(%{"order_by" => "Title", "dir" => "desc"}, ["Title"], [])
      {:ok, [{:desc, "Title"}]}

      iex> MySuperAppWeb.SortParams.parse(%{}, ["Title"], [{:asc, "Title"}])
      {:ok, [{:asc, "Title"}]}

      iex> MySuperAppWeb.SortParams.parse(%{"order_by" => "Title", "dir" => "up"}, ["Title"], [])
      {:error, "dir must be one of: asc, desc"}
  """
  def parse(%{"order_by" => order_by, "dir" => dir}, allowed, _default) do
    cond do
      not Map.has_key?(@directions, dir) ->
        {:error, "dir must be one of: asc, desc"}

      order_by not in allowed ->
        {:error, "order_by must be one of: " <> Enum.join(allowed, ", ")}

      true ->
        {:ok, [{Map.fetch!(@directions, dir), order_by}]}
    end
  end

  def parse(_params, _allowed, default), do: {:ok, default}
end
