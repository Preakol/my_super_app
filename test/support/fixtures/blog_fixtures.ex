defmodule MySuperApp.BlogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MySuperApp.Blog` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture() do
    {:ok, user} =
      MySuperApp.Accounts.register_user(%{
        login: "slots_operator222",
        email: "slotsoperator222@gmail.com",
        password: "123456789"
      })

    {:ok, post} =
      MySuperApp.Blog.create_post(%{
        "title" => "Poker: Strategies for Winning Big Jackpot",
        "body" =>
          "Poker is a game of skill, strategy, and psychological acumen. To excel, players must understand the nuances of hand rankings, betting patterns, and positional play. One crucial strategy is to play tight-aggressive, focusing on strong hands and betting confidently. Bluffing can also be effective, but it requires a keen sense of timing and opponent behavior. Reading your opponents and adjusting your strategy based on their tendencies is key. Additionally, managing your bankroll wisely ensures longevity in the game. By combining these strategies with practice and discipline, players can significantly increase their chances of success at the poker table.",
        "user_id" => user.id,
        "post_tags" => ["Poker"]
      })

    post
  end

  @doc """
  Generate a picture.
  """
  def picture_fixture() do
    {:ok, user} =
      MySuperApp.Accounts.register_user(%{
        login: "slots_operator222",
        email: "slotsoperator222@gmail.com",
        password: "123456789"
      })

    {:ok, post} =
      MySuperApp.Blog.create_post(%{
        "title" => "Poker: Strategies for Winning Big Jackpot",
        "body" =>
          "Poker is a game of skill, strategy, and psychological acumen. To excel, players must understand the nuances of hand rankings, betting patterns, and positional play. One crucial strategy is to play tight-aggressive, focusing on strong hands and betting confidently. Bluffing can also be effective, but it requires a keen sense of timing and opponent behavior. Reading your opponents and adjusting your strategy based on their tendencies is key. Additionally, managing your bankroll wisely ensures longevity in the game. By combining these strategies with practice and discipline, players can significantly increase their chances of success at the poker table.",
        "user_id" => user.id,
        "post_tags" => ["Poker"]
      })

    {:ok, picture} =
      MySuperApp.Blog.create_picture(%{
        "file_name" => Path.basename("https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_1.jpg"),
        "path" => "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_1.jpg",
        "post_id" => post.id
      })

    MySuperApp.Blog.get_picture(picture.id)
  end
end
