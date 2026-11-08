defmodule MySuperAppWeb.PicturesPageTest do
  use MySuperAppWeb.ConnCase

  alias MySuperApp.{Blog, Blog.Picture, Repo}
  alias MySuperAppWeb.PicturesPage

  @image File.read!("test/support/uploads/test_image.jpg")

  defp create_post(user, title) do
    {:ok, post} = Blog.create_post(%{"title" => title, "body" => "Body", "user_id" => user.id})
    post
  end

  defp create_picture(post_id, name) do
    {:ok, picture} =
      Blog.create_picture(%{
        "file_name" => name,
        "path" =>
          "https://res.cloudinary.com/test-cloud/image/upload/v1/test/posts/pictures/x/#{name}",
        "post_id" => post_id
      })

    picture
  end

  defp upload(view, form, name) do
    input =
      file_input(view, form, name, [%{name: "cat.jpg", content: @image, type: "image/jpeg"}])

    render_upload(input, "cat.jpg")
  end

  setup context do
    %{user: user} = admin = log_in_admin(context, 3)
    Map.put(admin, :post, create_post(user, "My post"))
  end

  test "uploads a picture and attaches it to a post", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/admin/pictures")
    view |> element("button", "Add new picture") |> render_click()

    upload(view, "#add-picture-form", :new_picture)

    assert view |> form("#add-picture-form", picture: %{post_id: post.id}) |> render_submit() =~
             "Picture added"

    assert %Picture{file_name: "cat.jpg", path: "https://res.cloudinary.com/test-cloud/" <> _} =
             Repo.get_by(Picture, post_id: post.id)

    assert has_element?(view, "#pictures", "My post")
  end

  test "reports a Cloudinary failure instead of crashing", %{conn: conn} do
    expect(MySuperApp.CloudinaryMock, :upload, fn _path, _opts -> {:error, :timeout} end)
    {:ok, view, _html} = live(conn, ~p"/admin/pictures")
    view |> element("button", "Add new picture") |> render_click()

    upload(view, "#add-picture-form", :new_picture)
    assert view |> form("#add-picture-form") |> render_submit() =~ "Image storage is unavailable"
    assert Repo.all(Picture) == []
  end

  test "assigns, unassigns and replaces a picture", %{conn: conn, post: post} do
    picture = create_picture(nil, "loose.jpg")
    {:ok, view, _html} = live(conn, ~p"/admin/pictures")

    view |> element("#picture-#{picture.id} button") |> render_click()

    assert view |> form("#assign-picture-form", picture: %{post_id: post.id}) |> render_submit() =~
             "Picture assigned"

    assert Repo.get(Picture, picture.id).post_id == post.id

    view |> element("#picture-#{picture.id} button") |> render_click()
    upload(view, "#replace-picture-form", :replacement)
    assert view |> form("#replace-picture-form") |> render_submit() =~ "Picture updated"
    assert Repo.get(Picture, picture.id).file_name == "cat.jpg"

    view |> element("#picture-#{picture.id} button") |> render_click()

    assert view |> element("#picture-modal button", "Unassign") |> render_click() =~
             "Picture unassigned"

    assert is_nil(Repo.get(Picture, picture.id).post_id)
  end

  test "deletes a picture and its Cloudinary file", %{conn: conn, post: post} do
    picture = create_picture(post.id, "bye.jpg")
    expect(MySuperApp.CloudinaryMock, :delete, fn "test/posts/pictures/x/bye" -> :ok end)
    {:ok, view, _html} = live(conn, ~p"/admin/pictures")

    view |> element("#picture-#{picture.id} button") |> render_click()
    view |> element("#picture-modal button", "Delete") |> render_click()
    assert view |> element("#delete-picture-modal-confirm") |> render_click() =~ "Picture deleted"
    refute Repo.get(Picture, picture.id)
  end

  test "filters by file name search and extension", %{conn: conn} do
    create_picture(nil, "sunset.png")
    create_picture(nil, "beach.jpg")
    {:ok, view, _html} = live(conn, ~p"/admin/pictures")

    view |> form("form[phx-change=change_extension]", extension: ".png") |> render_change()
    assert has_element?(view, "#pictures", "sunset.png")
    refute has_element?(view, "#pictures", "beach.jpg")
  end

  test "delete rule: own posts, unassigned pictures, or super admin" do
    me = %{id: 1, permissions: 3}
    assert PicturesPage.can_delete?(me, %Picture{post: nil})
    assert PicturesPage.can_delete?(me, %Picture{post: %Blog.Post{user_id: 1}})
    refute PicturesPage.can_delete?(me, %Picture{post: %Blog.Post{user_id: 2}})

    assert PicturesPage.can_delete?(%{me | permissions: 1}, %Picture{post: %Blog.Post{user_id: 2}})
  end
end
