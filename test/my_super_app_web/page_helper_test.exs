defmodule MySuperAppWeb.PageHelperTest do
  use ExUnit.Case, async: true

  alias MySuperAppWeb.PageHelper

  @rows Enum.map(1..12, &%{id: &1})

  test "paginate/3 returns the rows of the requested page" do
    assert PageHelper.paginate(@rows, 1, 5) |> Enum.map(& &1.id) == [1, 2, 3, 4, 5]
    assert PageHelper.paginate(@rows, 3, 5) |> Enum.map(& &1.id) == [11, 12]
    assert PageHelper.paginate(@rows, 4, 5) == []
  end

  test "total_pages/2 is at least one, even for an empty list" do
    assert PageHelper.total_pages(@rows, 5) == 3
    assert PageHelper.total_pages([], 5) == 1
  end

  test "clamp_page/3 keeps the page in range" do
    assert PageHelper.clamp_page(3, Enum.take(@rows, 10), 5) == 2
    assert PageHelper.clamp_page(0, @rows, 5) == 1
  end

  test "resize_page/3 keeps the first visible row on screen" do
    assert PageHelper.resize_page(3, 5, 10) == 2
    assert PageHelper.resize_page(2, 10, 5) == 3
    assert PageHelper.resize_page(1, 5, 10) == 1
  end

  test "toggle_sort/2 flips the current column and resets others to ascending" do
    assert PageHelper.toggle_sort(%{column: :login, direction: :asc}, :login) == %{
             column: :login,
             direction: :desc
           }

    assert PageHelper.toggle_sort(%{column: :login, direction: :desc}, :login) == %{
             column: :login,
             direction: :asc
           }

    assert PageHelper.toggle_sort(%{column: :login, direction: :desc}, :email) == %{
             column: :email,
             direction: :asc
           }
  end

  test "sort_rows/2 sorts strings and datetimes in both directions" do
    rows = [
      %{login: "bob", at: ~U[2024-01-02 00:00:00Z]},
      %{login: "alice", at: ~U[2024-01-10 00:00:00Z]},
      %{login: "carol", at: ~U[2023-12-31 00:00:00Z]}
    ]

    assert rows
           |> PageHelper.sort_rows(%{column: :login, direction: :asc})
           |> Enum.map(& &1.login) == ~w(alice bob carol)

    assert rows |> PageHelper.sort_rows(%{column: :at, direction: :desc}) |> Enum.map(& &1.login) ==
             ~w(alice bob carol)

    assert rows |> PageHelper.sort_rows(%{column: :at, direction: :asc}) |> Enum.map(& &1.login) ==
             ~w(carol bob alice)

    assert PageHelper.sort_rows(rows, %{column: nil, direction: :asc}) == rows
  end

  test "date_range/2 orders complete ranges and ignores incomplete ones" do
    assert PageHelper.date_range("2024-03-10", "2024-03-01") == {"2024-03-01", "2024-03-10"}
    assert PageHelper.date_range("2024-03-01", "") == :none
    assert PageHelper.date_range(nil, "2024-03-01") == :none
    assert PageHelper.date_range("2024-13-01", "2024-03-01") == :none
  end

  test "parse_positive/1 rejects junk" do
    assert PageHelper.parse_positive("10") == {:ok, 10}
    assert PageHelper.parse_positive("0") == :error
    assert PageHelper.parse_positive("abc") == :error
  end
end
