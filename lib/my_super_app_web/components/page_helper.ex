defmodule MySuperAppWeb.PageHelper do
  @moduledoc false

  def sort_by_collumn(list, collumn, direction), do: sort_helper(list, collumn, direction)

  defp sort_helper(list, collumn, "DESC"), do: Enum.sort_by(list, &[&1[collumn]], :desc)
  defp sort_helper(list, collumn, "ASC"), do: Enum.sort_by(list, &[&1[collumn]], :desc)

  def select_content_for_page(assigns, content) do
    content
    |> Enum.slice(
      (assigns.current_page * assigns.page_size - assigns.page_size)..(assigns.current_page * assigns.page_size - 1)
    )
  end

  def update_current_page(socket, content) do
    ceil((length(content) - 1) / socket.assigns.page_size)
    |> max(1)
    |> min(socket.assigns.current_page)
  end

  def change_page_size(_socket, 5), do: [page_size: 5]

  def change_page_size(socket, 10),
    do: [page_size: 10, current_page: ceil(socket.assigns.current_page / 2)]
end
