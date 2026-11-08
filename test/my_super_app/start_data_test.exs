defmodule MySuperApp.StartDataTest do
  use MySuperApp.DataCase

  alias MySuperApp.{Accounts, Blog.Post, Operator, Repo, SiteConfig, StartData, User}

  test "seeds demo accounts, operators, site configs and posts" do
    assert {:ok, :seeded} = StartData.run("demo-password")

    assert Repo.aggregate(User, :count) == 11
    assert Repo.aggregate(Operator, :count) == 3
    assert Repo.aggregate(SiteConfig, :count) == 5
    assert Repo.aggregate(Post, :count) == 6

    assert Accounts.get_user_by_email_or_login_and_password("admin@example.com", "demo-password")

    assert Accounts.get_user(Repo.get_by!(User, login: "nora").id).role.name ==
             "Head of Northwind Gaming"

    assert Accounts.get_user(Repo.get_by!(User, login: "oscar").id).role.name == "viewer"

    assert Repo.all(from u in User, where: not like(u.email, "%@example.com")) == []
    assert Repo.all(from p in Post, where: not is_nil(p.published_at)) |> length() == 4
  end

  test "does nothing when the database already has users" do
    MySuperApp.AccountsFixtures.user_fixture()

    assert {:ok, :skipped} = StartData.run("demo-password")
    assert Repo.aggregate(Operator, :count) == 0
  end
end
