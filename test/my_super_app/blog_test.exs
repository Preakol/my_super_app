defmodule MySuperApp.BlogTest do
  use MySuperApp.DataCase

  alias MySuperApp.Blog

  describe "posts" do
    alias MySuperApp.Blog.Post

    import MySuperApp.BlogFixtures

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()

      update_attrs = %{
        "user_id" => post.user_id,
        "title" => "some updated title",
        "body" => "some updated body"
      }

      assert {:ok, %Post{} = post} = Blog.update_post(post, update_attrs)
      assert post.title == "some updated title"
      assert post.body == "some updated body"
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Blog.delete_post(post)
      assert nil == Blog.get_post(post.id)
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Blog.change_post(post)
    end
  end

  describe "pictures" do
    alias MySuperApp.Blog.Picture

    import MySuperApp.BlogFixtures

    @invalid_attrs %{"path" => 1, "file_name" => 1}

    test "list_pictures/0 returns all pictures" do
      picture = picture_fixture()
      assert picture in Blog.list_pictures()
    end

    test "get_picture/1 returns the picture with given id" do
      picture = picture_fixture()
      assert Blog.get_picture(picture.id) == picture
    end

    test "create_picture/1 with valid data creates a picture" do
      post = post_fixture()

      valid_attrs = %{
        "file_name" => Path.basename("https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_1.jpg"),
        "path" => "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_1.jpg",
        "post_id" => post.id
      }

      assert {:ok, %Picture{}} = Blog.create_picture(valid_attrs)
    end

    test "create_picture/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Blog.create_picture(@invalid_attrs)
    end

    test "update_picture/2 with valid data updates the picture" do
      picture = picture_fixture()
      update_attrs = %{
        "file_name" => Path.basename("https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_2.jpg"),
        "path" => "https://res.cloudinary.com/dkcseoren/image/upload/start_pictures/funny_cat_2.jpg"
      }

      assert {:ok, %Picture{}} = Blog.update_picture(picture, update_attrs)
    end

    test "update_picture/2 with invalid data returns error changeset" do
      picture = picture_fixture()
      assert {:error, %Ecto.Changeset{}} = Blog.update_picture(picture, @invalid_attrs)
      assert picture == Blog.get_picture(picture.id)
    end

    test "delete_picture/1 deletes the picture" do
      picture = picture_fixture()
      assert {:ok, %Picture{}} = Blog.delete_picture(picture)
      assert nil == Blog.get_picture(picture.id)
    end

    test "change_picture/1 returns a picture changeset" do
      picture = picture_fixture()
      assert %Ecto.Changeset{} = Blog.change_picture(picture)
    end
  end
end
