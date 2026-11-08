defmodule MySuperApp.StartData do
  @moduledoc """
  Demo data for local development and the public demo: a super admin, three
  fictional operators with their staff, brands, site configs and blog posts.

  Every account uses the password passed to `run/1`. All names, emails and
  brands are made up; emails use the reserved `example.com` domain.
  """

  import Ecto.Query, only: [from: 2]

  alias MySuperApp.{Accounts, Authority, Blog, CasinosAdmins, Repo, Role, User}
  alias MySuperApp.SiteConfigManagement

  @operators [
    %{name: "Northwind Gaming", head: "nora", brands: ["Aurora Slots", "Northern Lights Bingo"]},
    %{name: "Blue Harbor Games", head: "harper", brands: ["Harbor Bet"]},
    %{name: "Lucky Lantern", head: "leo", brands: ["Lantern Live", "Comet Casino"]}
  ]

  @unused_brands ["Pinecone Poker", "Starlight Keno"]

  @staff [
    {"mia", "Northwind Gaming", "role_manager"},
    {"oscar", "Northwind Gaming", "viewer"},
    {"ivy", "Blue Harbor Games", "viewer"},
    {"theo", "Lucky Lantern", "role_manager"}
  ]

  @readers ~w(sam riley jordan)

  @posts [
    %{
      author: "nora",
      title: "Welcome to the demo blog",
      body:
        "This blog is part of a small Phoenix LiveView project. Posts are written by admins and published from the admin panel.",
      tags: ["announcements"],
      published: true
    },
    %{
      author: "harper",
      title: "Roles and permissions explained",
      body:
        "Every operator gets three roles: a head, a role manager and a viewer. Lower levels see less of the admin panel.",
      tags: ["admin", "guides"],
      published: true
    },
    %{
      author: "leo",
      title: "Release notes for the spring update",
      body:
        "The admin tables now support sorting, filtering by date and adjustable page sizes. Search works on logins and ids.",
      tags: ["announcements", "release"],
      published: true
    },
    %{
      author: "mia",
      title: "How brands and site configs fit together",
      body:
        "A site config links a brand to an operator. Each brand can belong to one operator at a time and can be switched off.",
      tags: ["guides"],
      published: true
    },
    %{
      author: "theo",
      title: "Draft: ideas for the next sprint",
      body:
        "Better empty states, keyboard shortcuts for the admin tables and an audit log for role changes.",
      tags: ["planning"],
      published: false
    },
    %{
      author: "sam",
      title: "Notes from a first-time reader",
      body:
        "The users page lists everyone who signed up, and the API exposes published posts as JSON.",
      tags: [],
      published: false
    }
  ]

  @doc """
  Inserts the demo data in one transaction. Returns `{:ok, :seeded}`, or
  `{:ok, :skipped}` when the database already has users.
  """
  def run(password) when is_binary(password) do
    if Repo.exists?(User) do
      {:ok, :skipped}
    else
      Repo.transaction(fn -> seed(password) end)
    end
  end

  defp seed(password) do
    super_admin_role = Repo.insert!(%Role{name: "super_admin", permissions: 1})
    register!("admin", password, super_admin_role.id)

    for %{name: name, head: head} <- @operators do
      user = register!(head, password)
      ok!(CasinosAdmins.create_operator(%{"name" => name, "user_id" => "#{user.id}"}))
    end

    for {login, operator, role} <- @staff do
      register!(login, password, role_id(operator, role))
    end

    Enum.each(@readers, &register!(&1, password))

    Repo.insert_all("brands", Enum.map(all_brands(), &%{name: &1}))

    for %{name: name, brands: brands} <- @operators, brand <- brands do
      operator_id = operator_id(name)
      ok!(SiteConfigManagement.create_site_config(%{brand: brand, operator_id: operator_id}))
    end

    @posts
    |> Enum.with_index()
    |> Enum.each(fn {post, index} -> create_post!(post, index) end)

    :seeded
  end

  defp all_brands, do: Enum.flat_map(@operators, & &1.brands) ++ @unused_brands

  defp register!(login, password, role_id \\ nil) do
    ok!(
      Accounts.register_user(%{
        login: login,
        email: "#{login}@example.com",
        password: password,
        role_id: role_id
      })
    )
  end

  defp create_post!(post, index) do
    author = Repo.get_by!(User, login: post.author)

    published_at =
      if post.published,
        do: DateTime.utc_now(:second) |> DateTime.add(-index, :day)

    ok!(
      Blog.create_post(%{
        "title" => post.title,
        "body" => post.body,
        "user_id" => author.id,
        "published_at" => published_at,
        "tags" => Enum.map(post.tags, &%{"title" => &1})
      })
    )
  end

  defp operator_id(name),
    do: Repo.one!(from o in MySuperApp.Operator, where: o.name == ^name, select: o.id)

  defp role_id(operator, role_name) do
    operator
    |> Authority.get_roles_by_operator(false)
    |> Enum.find(&(&1.name == role_name))
    |> case do
      %{id: id} -> id
      nil -> raise ArgumentError, "role #{role_name} not found for #{operator}"
    end
  end

  defp ok!({:ok, value}), do: value

  defp ok!({:error, reason}),
    do: raise(ArgumentError, "could not insert demo data: #{inspect(reason)}")
end
