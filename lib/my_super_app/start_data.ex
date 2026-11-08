defmodule MySuperApp.StartData do
  @moduledoc false

  alias MySuperApp.{Repo, Accounts, Role, SiteConfig, CasinosAdmins, Authority, Blog}
  alias Faker.{StarWars, Internet}

  def run() do
    %Role{name: "super_admin", permissions: 1, operator_id: nil}
    |> Repo.insert()

    Accounts.register_user(%{
      login: "superadmin",
      email: "super@admin.com",
      password: "superadmin",
      role_id: 1
    })

    Accounts.register_user(%{login: "Gosha", email: "gosha@doto.com", password: "Gosha2001"})

    Accounts.register_user(%{login: "Toha", email: "toha@pro_doto.com", password: "Toha2005"})

    Accounts.register_user(%{login: "Zhenya", email: "jojo@jojo.com", password: "Zhenya2004"})

    for id <- 2..4 do
      CasinosAdmins.create_operator(%{
        "name" => StarWars.character(),
        "user_id" => id |> Integer.to_string()
      })
    end

    for _ <- 1..10 do
      character = StarWars.character()
      Accounts.register_user(%{login: character, email: Internet.email(), password: character})
    end

    brands = [
      %{name: "Bitcasino"},
      %{name: "Sportsbet"},
      %{name: "Livecasino"},
      %{name: "Bombay"},
      %{name: "Luckyslots"},
      %{name: "Hub88"},
      %{name: "Moneyball-IO"},
      %{name: "Aposta10"},
      %{name: "Slots"}
    ]

    Repo.insert_all("brands", brands)

    %SiteConfig{brand: "Livecasino", operator_id: 1}
    |> Repo.insert()

    for user_id <- 1..10 do
      tags =
        case Enum.random(0..7) do
          0 ->
            []

          n ->
            Enum.map(1..n, fn _ -> %{"title" => Faker.StarWars.planet()} end)
        end

      post_params =
        %{
          "title" => Faker.Lorem.sentence(1..3),
          "body" => Faker.Lorem.paragraph(3..13),
          "user_id" => user_id
        }
        |> Map.merge(if tags == [], do: %{}, else: %{"tags" => Enum.uniq(tags)})

      Blog.create_post(post_params)
    end

    for {path, post_id} <- start_pictures() |> Enum.with_index(1) do
      picture_params = %{
        "file_name" =>
          path
          |> String.split("/")
          |> Enum.at(-1),
        "path" => path,
        "post_id" => post_id
      }

      Blog.create_picture(picture_params)
    end
  end

  def start_pictures() do
    [
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_1.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_2.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_3.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_4.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_5.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_6.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_7.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_8.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_9.jpg",
      "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_10.jpg"
    ]
  end

  def register_admins(amount) when amount in [1, 2, 3] do
    CasinosAdmins.get_operator_names()
    |> Enum.each(fn operator_name ->
      Authority.get_roles_by_operator(operator_name, false)
      |> Enum.each(fn role ->
        create_multiple_users_for_role(role.id, amount)
      end)
    end)
  end

  defp create_multiple_users_for_role(role_id, amount) do
    Enum.each(1..amount, fn _ ->
      generate_admin_user_params(role_id)
      |> Accounts.register_user()
    end)
  end

  defp generate_admin_user_params(role_id) do
    login = Internet.user_name()

    %{
      login: login,
      email: "#{login}@gmail.com",
      password: login,
      role_id: role_id
    }
  end
end
