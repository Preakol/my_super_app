defmodule MySuperAppWeb.PageHelper do
  @moduledoc """
  Pure helpers for paging and sorting the in-memory lists shown in admin tables.

  A sort is `%{column: atom() | nil, direction: :asc | :desc}`.
  """

  @type sort :: %{column: atom() | nil, direction: :asc | :desc}

  @spec paginate([row], pos_integer(), pos_integer()) :: [row] when row: term()
  def paginate(rows, page, page_size),
    do: rows |> Enum.drop((page - 1) * page_size) |> Enum.take(page_size)

  @spec total_pages(list(), pos_integer()) :: pos_integer()
  def total_pages(rows, page_size), do: max(1, ceil(length(rows) / page_size))

  @doc "Keeps `page` inside the valid range, e.g. after the last row of the last page was deleted."
  @spec clamp_page(integer(), list(), pos_integer()) :: pos_integer()
  def clamp_page(page, rows, page_size), do: page |> max(1) |> min(total_pages(rows, page_size))

  @doc "The page that still shows the first row of `current_page` after the page size changes."
  @spec resize_page(pos_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def resize_page(current_page, old_size, new_size),
    do: div((current_page - 1) * old_size, new_size) + 1

  @doc "Clicking the sorted column flips the direction; another column starts ascending."
  @spec toggle_sort(sort(), atom()) :: sort()
  def toggle_sort(%{column: column, direction: :asc}, column),
    do: %{column: column, direction: :desc}

  def toggle_sort(_sort, column), do: %{column: column, direction: :asc}

  @spec sort_rows([map()], sort()) :: [map()]
  def sort_rows(rows, %{column: nil}), do: rows

  def sort_rows(rows, %{column: column, direction: direction}) do
    Enum.sort_by(rows, &Map.get(&1, column), sorter(direction, rows, column))
  end

  @doc "Parses a positive integer sent by the browser (page number, page size)."
  @spec parse_positive(String.t()) :: {:ok, pos_integer()} | :error
  def parse_positive(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> :error
    end
  end

  @doc """
  Turns two `<input type="date">` values into an ordered `{start, end}` pair of
  ISO-8601 strings, or `:none` while the range is incomplete or invalid.
  """
  @spec date_range(String.t() | nil, String.t() | nil) :: {String.t(), String.t()} | :none
  def date_range(start_date, end_date) do
    with {:ok, from} <- parse_date(start_date),
         {:ok, to} <- parse_date(end_date) do
      [first, last] = Enum.sort([from, to], Date)
      {Date.to_iso8601(first), Date.to_iso8601(last)}
    else
      :error -> :none
    end
  end

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  defp parse_date(_value), do: :error

  defp sorter(direction, rows, column) do
    case Enum.find_value(rows, &Map.get(&1, column)) do
      %module{} when module in [DateTime, NaiveDateTime, Date] -> {direction, module}
      _ -> direction
    end
  end

  # Pre-HEEx API, used by pages not yet ported; removed together with Surface.
  def sort_by_collumn(list, collumn, "DESC"), do: Enum.sort_by(list, &[&1[collumn]], :desc)
  def sort_by_collumn(list, collumn, "ASC"), do: Enum.sort_by(list, &[&1[collumn]], :desc)

  def select_content_for_page(assigns, content),
    do: paginate(content, assigns.current_page, assigns.page_size)

  def update_current_page(socket, content) do
    ceil((length(content) - 1) / socket.assigns.page_size)
    |> max(1)
    |> min(socket.assigns.current_page)
  end

  def change_page_size(_socket, 5), do: [page_size: 5]

  def change_page_size(socket, 10),
    do: [page_size: 10, current_page: ceil(socket.assigns.current_page / 2)]
end
