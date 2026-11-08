defmodule MySuperApp.Jobs.Email do
  @moduledoc "Notifies a post author by email when the post is published or unpublished."
  use Oban.Worker, queue: :email

  import Swoosh.Email

  alias MySuperApp.Mailer

  def get_post_publishing_args(post) do
    Map.update!(post, :user, fn user ->
      user
      |> Map.from_struct()
      |> Map.take([:id, :email, :login])
    end)
    |> Map.from_struct()
    |> Map.take([:id, :title, :published_at, :user])
  end

  @impl Worker
  def perform(%Job{args: %{"user" => user} = args}) do
    case args |> build_email(user) |> Mailer.deliver() do
      {:ok, _metadata} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def build_email(%{"published_at" => nil} = args, user) do
    user
    |> base_email()
    |> subject("Your Post was Unpublished.")
    |> html_body(
      card("Post Unpublished", """
      Hello <strong>#{escape(user["login"])}</strong>, your post titled
      <strong>"#{escape(args["title"])}"</strong> has been unpublished.
      We will contact you about future updates on it.
      """)
    )
  end

  def build_email(args, user) do
    user
    |> base_email()
    |> subject("Your Post was Published!")
    |> html_body(
      card("Post Published!", """
      Hello <strong>#{escape(user["login"])}</strong>, congratulations! Your post titled
      <strong>"#{escape(args["title"])}"</strong> has been successfully published.
      """)
    )
  end

  defp base_email(user) do
    new()
    |> to(user["email"])
    |> from(Application.fetch_env!(:my_super_app, :mail_from))
  end

  defp card(heading, text) do
    """
    <div style="background-color: #ffffff; padding: 20px; text-align: center; border: 1px solid #000; max-width: 600px; margin: 0 auto;">
      <h1 style="font-size: 24px; color: #000000; font-weight: bold;">#{heading}</h1>
      <p style="color: #000000; font-size: 16px;">#{text}</p>
    </div>
    """
  end

  defp escape(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
