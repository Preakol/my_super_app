defmodule MySuperApp.Jobs.EmailTest do
  use MySuperApp.DataCase, async: true

  import Swoosh.TestAssertions

  alias MySuperApp.Jobs.Email

  @user %{"email" => "author@example.com", "login" => "author"}

  test "sends a 'published' email when the post has a publish date" do
    args = %{"title" => "Hello", "published_at" => "2026-01-01T00:00:00Z", "user" => @user}

    assert :ok = perform_job(args)

    assert_email_sent(fn email ->
      assert email.subject == "Your Post was Published!"
      assert email.to == [{"", "author@example.com"}]
      assert email.from == {"", "my-super-app@example.com"}
      assert email.html_body =~ "Hello"
    end)
  end

  test "sends an 'unpublished' email when the publish date is cleared" do
    assert :ok = perform_job(%{"title" => "Hello", "published_at" => nil, "user" => @user})

    assert_email_sent(subject: "Your Post was Unpublished.")
  end

  test "escapes user-provided text in the email body" do
    email = Email.build_email(%{"title" => "<script>x</script>", "published_at" => nil}, @user)

    refute email.html_body =~ "<script>"
    assert email.html_body =~ "&lt;script&gt;"
  end

  defp perform_job(args), do: Email.perform(%Oban.Job{args: args})
end
