defmodule MySuperAppWeb.HomeLive do
  use MySuperAppWeb, :surface_live_view

  alias Moon.Design.Button


  def mount(_params, session, socket) do
    user = MySuperApp.Accounts.get_user_by_session_token(session["user_token"])

    {:ok, assign(socket, current_user: user)}
  end
  
  def render(assigns) do
    ~F"""
    <Button class="bg-krillin" left_icon="generic_settings" size="xl" as="a" href="https://www.nyan.cat/" animation="pulse" >BIM BOM</Button>
    """
  end
end
