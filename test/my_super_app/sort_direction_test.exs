defmodule MySuperApp.SortDirectionTest do
  use MySuperApp.DataCase, async: true

  alias MySuperApp.{Accounts, Blog, SortDirection}

  doctest SortDirection

  test "unknown directions raise instead of becoming atoms" do
    assert_raise ArgumentError, fn -> SortDirection.parse!("sideways") end

    assert_raise ArgumentError, fn ->
      Accounts.get_users_by_filters(%{
        search: "",
        operator: nil,
        role: nil,
        sorting: [{:id, "sideways"}]
      })
    end
  end

  test "Blog rejects sort columns outside the whitelist" do
    assert_raise ArgumentError, ~r/unknown sort column/, fn ->
      Blog.list_posts([{:asc, "Hashed Password"}])
    end

    assert Blog.list_posts([{:asc, "Title"}]) == []
    assert Blog.list_pictures([{:desc, "File Name"}]) == []
  end
end
