defmodule MySuperApp.Jobs.Email do
  @moduledoc false
  use Oban.Worker, queue: :email

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
  def perform(%Job{args: %{"published_at" => nil, "user" => user} = args}) do
    SendGrid.Email.build()
    |> SendGrid.Email.add_to(user["email"])
    |> SendGrid.Email.put_from(mail_from())
    |> SendGrid.Email.put_subject("Your Post was Unpublished.")
    |> SendGrid.Email.put_html("""
    <div style=\"background-color: #ffffff; padding: 20px; text-align: center; border: 1px solid #000; max-width: 600px; margin: 0 auto;\">
      <h1 style=\"font-size: 24px; color: #000000; font-weight: bold;\">Post Unpublished</h1>
      <p style=\"color: #000000; font-size: 16px; margin-bottom: 20px;\">
        Hello
        <strong style='color: #FFD700;'>#{user["login"]}</strong>,
        your post titled
        <strong style='color: #FFD700;'>\"#{args["title"]}\"</strong>
        has been unpublished:(
      </p>
      <p style=\"color: #000000; font-size: 16px; margin-bottom: 20px;\">
        We will contact you about future updates on it.
      </p>
    </div>
    """)
    |> SendGrid.Mail.send()

    :ok
  end

  def perform(%Job{args: %{"user" => user} = args}) do
    SendGrid.Email.build()
    |> SendGrid.Email.add_to(user["email"])
    |> SendGrid.Email.put_from(mail_from())
    |> SendGrid.Email.put_subject("Your Post was Published!")
    |> SendGrid.Email.put_html("""
    <div style=\"background-color: #ffffff; padding: 20px; text-align: center; border: 1px solid #000; max-width: 600px; margin: 0 auto;\">
      <h1 style=\"font-size: 24px; color: #000000; font-weight: bold;\">Post Published!</h1>
      <p style=\"color: #000000; font-size: 16px; margin-bottom: 20px;\">
        Hello
        <strong style='color: #FFD700;'>#{user["login"]}</strong>,
        congratulations! Your post titled
        <strong style='color: #FFD700;'>\"#{args["title"]}\"</strong>
        has been successfully published.
      </p>
    </div>
    """)
    |> SendGrid.Mail.send()

    :ok
  end

  defp mail_from, do: Application.fetch_env!(:my_super_app, :mail_from)
end
