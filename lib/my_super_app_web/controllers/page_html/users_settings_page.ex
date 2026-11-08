defmodule MySuperAppWeb.UsersSettingsPage do
  @moduledoc false
  use MySuperAppWeb, :surface_live_view

  alias MySuperApp.{Accounts, Cloudinary}

  alias Moon.Design.{Button, Form, Form.Input, Form.Field, Progress}

  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
       avatar_form: to_form(Accounts.change_avatar_image()),
       login_form: to_form(Accounts.change_user_login()),
       login_form_current_password: nil,
       email_form: to_form(Accounts.change_user_email()),
       email_form_current_password: nil
     )
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  def handle_event("validate_avatar", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_avatar", _params, socket) do
    user = socket.assigns.current_user

    results =
      consume_uploaded_entries(socket, :avatar, fn meta, _entry ->
        {:ok,
         Cloudinary.upload(meta.path, folder: Cloudinary.folder("avatars"), public_id: user.login)}
      end)

    Process.send_after(self(), :clear_flash, 3000)

    case results do
      [{:ok, %{url: url}}] ->
        Accounts.update_user_avatar(user.id, url)

        {:noreply,
         socket
         |> put_flash(:info, "Avatar updated")
         |> assign(current_user: Map.put(user, :avatar_image, url))}

      [{:error, _reason}] ->
        {:noreply, put_flash(socket, :error, "Avatar upload failed, please try again later")}

      [] ->
        {:noreply, put_flash(socket, :error, "Choose an image first")}
    end
  end

  def handle_event(
        "validate_email",
        %{"user" => %{"current_password" => password, "email" => email}},
        socket
      ) do
    email_form =
      Accounts.change_user_email(%{"email" => email})
      |> Map.put(:action, :insert)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event(
        "update_email",
        %{"user" => %{"current_password" => password, "email" => email}},
        socket
      ) do
    Accounts.get_user(socket.assigns.current_user.id)
    |> Accounts.apply_user_email(password, %{"email" => email})
    |> case do
      {:ok, _applied_user} ->
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
         socket
         |> put_flash(:info, "Email updated")
         |> assign(
           email_form_current_password: nil,
           current_user: Map.put(socket.assigns.current_user, :email, email),
           email_form: to_form(Accounts.change_user_email())
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, email_form: to_form(changeset))}
    end
  end

  def handle_event(
        "validate_login",
        %{"user" => %{"current_password" => password, "login" => login}},
        socket
      ) do
    login_form =
      Accounts.change_user_login(%{"login" => login})
      |> Map.put(:action, :insert)
      |> to_form()

    {:noreply, assign(socket, login_form: login_form, login_form_current_password: password)}
  end

  def handle_event(
        "update_login",
        %{"user" => %{"current_password" => password, "login" => login}},
        socket
      ) do
    Accounts.get_user(socket.assigns.current_user.id)
    |> Accounts.apply_user_login(password, %{"login" => login})
    |> case do
      {:ok, _applied_user} ->
        Process.send_after(self(), :clear_flash, 3000)

        {:noreply,
         socket
         |> put_flash(:info, "Login updated")
         |> assign(
           login_form_current_password: nil,
           current_user: Map.put(socket.assigns.current_user, :login, login),
           login_form: to_form(Accounts.change_user_login())
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, login_form: to_form(changeset))}
    end
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end
end
