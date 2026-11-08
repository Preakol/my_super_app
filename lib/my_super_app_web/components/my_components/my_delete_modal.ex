defmodule MySuperAppWeb.MyDeleteModal do
  @moduledoc false
  use Moon.StatefulComponent

  alias Moon.Design.{Modal, Button}

  prop(is_open, :boolean, default: false)
  prop(header, :string, default: "Delete?")
  prop(on_delete, :event, from_context: :on_delete, required: true)
  prop(on_toggle, :event, from_context: :on_toggle, required: true)

  def handle_event("do_nothing", _, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~F"""
    <div>
      <Modal {=@id} {=@is_open} on_close="do_nothing">
        <Modal.Backdrop />
        <Modal.Panel>
          <div class="border-b-[0.063rem] border-beerus pt-5 pb-4 px-6 relative">
            <h3 class="text-moon-18 text-bulma font-medium">{@header}</h3>
          </div>
          <div class="flex gap-2 p-4 justify-end pt-2">
            <Button variant="outline"
              on_click={@on_toggle}
              values={action: "close"}
              left_icon="controls_close"
              class="hover:text-goku hover:bg-bulma"
            >Cancel</Button>
            <Button on_click={@on_delete}
              left_icon="generic_delete"
              class="border border-bulma bg-bulma text-goku hover:text-bulma hover:bg-goku"
            >Delete</Button>
          </div>
        </Modal.Panel>
      </Modal>
    </div>
    """
  end
end
