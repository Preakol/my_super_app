defmodule MySuperAppWeb.UsersSettingsPage do
  @moduledoc false
  use MySuperAppWeb, :live_view

  alias MySuperApp.{Accounts, Cloudinary}

  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       page_title: "Account settings",
       current_user: Accounts.get_user_by_session_token(session["user_token"]),
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

  def render(assigns) do
    ~H"""
    <h1 class="mb-8 text-2xl font-semibold text-zinc-900">Account settings</h1>
    <div class="grid gap-10 md:grid-cols-3">
      <section>
        <h2 class="mb-4 text-lg font-semibold text-zinc-900">Avatar</h2>
        <form
          id="avatar-form"
          phx-change="validate_avatar"
          phx-submit="save_avatar"
          class="flex flex-col gap-4"
        >
          <.avatar
            :if={@uploads.avatar.entries == []}
            user={@current_user}
            class="h-20 w-20 text-2xl"
          />
          <div :for={entry <- @uploads.avatar.entries} class="flex flex-col gap-2">
            <.live_img_preview entry={entry} class="h-20 w-20 rounded-full object-cover" />
            <progress value={entry.progress} max="100" class="w-full">
              <%= entry.progress %>%
            </progress>
            <p :for={err <- upload_errors(@uploads.avatar, entry)} class="text-sm text-red-600">
              <%= upload_error_message(err) %>
            </p>
          </div>
          <label for={@uploads.avatar.ref} class="text-sm font-semibold text-zinc-800">
            Choose an image (.jpg, .png, up to 10 MB)
          </label>
          <.live_file_input upload={@uploads.avatar} class="text-sm" />
          <p :for={err <- upload_errors(@uploads.avatar)} class="text-sm text-red-600">
            <%= upload_error_message(err) %>
          </p>
          <.button disabled={@uploads.avatar.entries == []}>Upload photo</.button>
        </form>
      </section>

      <section>
        <h2 class="mb-4 text-lg font-semibold text-zinc-900">Login</h2>
        <.simple_form
          for={@login_form}
          id="login-form"
          phx-change="validate_login"
          phx-submit="update_login"
          autocomplete="off"
        >
          <.input field={@login_form[:login]} label="New login" />
          <.input
            name="user[current_password]"
            id="login_current_password"
            type="password"
            label="Current password"
            value={@login_form_current_password}
          />
          <:actions>
            <.button class="w-full">Change login</.button>
          </:actions>
        </.simple_form>
      </section>

      <section>
        <h2 class="mb-4 text-lg font-semibold text-zinc-900">Email</h2>
        <.simple_form
          for={@email_form}
          id="email-form"
          phx-change="validate_email"
          phx-submit="update_email"
          autocomplete="off"
        >
          <.input field={@email_form[:email]} type="email" label="New email" />
          <.input
            name="user[current_password]"
            id="email_current_password"
            type="password"
            label="Current password"
            value={@email_form_current_password}
          />
          <:actions>
            <.button class="w-full">Change email</.button>
          </:actions>
        </.simple_form>
      </section>
    </div>
    """
  end
end
