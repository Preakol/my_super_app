defmodule MySuperApp.AdminPubSub do
  @moduledoc false

  alias MySuperApp.{User, Role, Operator, SiteConfig, Blog.Picture, Blog.Post}

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(MySuperApp.PubSub, topic)
  end

  def broadcast(%Post{} = post, :publish_update) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "blog", :publish_update)
    post
  end

  def broadcast({:ok, %Role{} = role}, :create) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "roles", :roles_updated)
    {:ok, role}
  end
  def broadcast({:ok, %Role{} = role}, :update) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "roles", :roles_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :users_updated)
    {:ok, role}
  end
  def broadcast({:ok, %Role{} = role}, :delete) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "roles", :roles_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "operators", :users_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :users_updated)
    {:ok, role}
  end

  def broadcast(%Operator{} = operator, :create) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "operators", :operators_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :operators_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "roles", :operators_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "site_configs", :operators_updated)
    operator
  end
  def broadcast({:ok, %Operator{} = operator}, :delete) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "operators", :operators_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :users_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "roles", :roles_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "site_configs", :site_configs_updated)
    {:ok, operator}
  end

  def broadcast({:ok, %User{} = user}, :update_role) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :users_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "operators", :users_updated)
    {:ok, user}
  end
  def broadcast({:ok, %User{} = user}, :update_email) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :users_updated)
    {:ok, user}
  end

  def broadcast({:error, _} = error, _), do: error

  def broadcast({:ok, %User{} = user}) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "users", :users_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "operators", :users_updated)
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "blog", :blog_updated)
    {:ok, user}
  end

  def broadcast({:ok, %SiteConfig{} = site_config}) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "site_configs", :site_configs_updated)
    {:ok, site_config}
  end

  def broadcast({:ok, %Post{} = post}) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "blog", :blog_updated)
    {:ok, post}
  end
  def broadcast({:ok, %Picture{} = picture}) do
    Phoenix.PubSub.broadcast(MySuperApp.PubSub, "blog", :blog_updated)
    {:ok, picture}
  end

  def broadcast({:error, _} = error), do: error
end
