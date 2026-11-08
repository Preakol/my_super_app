defmodule MySuperAppWeb.MySwitcher do
  @moduledoc false

  use Moon.StatelessComponent

  alias Moon.Components.AsComponent

  prop(checked, :any, default: false)
  prop(disabled, :boolean, default: false)
  prop(on_change, :event)
  prop(values, :keyword, default: [])

  prop(id, :string)
  prop(testid, :string)
  prop(switcher_class, :css_class)
  prop(class, :css_class)

  @spec render(map) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~F"""
    <AsComponent
      {=@id}
      {=@testid}
      {=@values}
      on_click={@on_change}
      value={@checked}
      as="button"
      attrs={[disabled: @disabled, type: "button"]}
      class={merge([
        [
          "block border border-bulma rounded-full transition",
          "w-64 h-8 p-1",
          (@checked && "bg-goku") || "bg-bulma",
          "cursor-pointer": !@disabled,
          "opacity-60 cursor-not-allowed select-none": @disabled
        ],
        @class
      ])}
    >
      <span class="block relative h-full w-full">
        <span
          aria-hidden="true"
          class={merge([
            [
              "z-5 absolute top-1/2 -translate-y-1/2 translate-x-0 shadow-moon-sm pointer-events-none rounded-full",
              "bg-bulma text-goku transition-all font-semibold",
              "w-36 ltr:left-[calc(100%-144px)] rtl:right-[calc(100%-144px)]",
              "bg-goku text-bulma ltr:left-0 rtl:right-0": !@checked
            ],
            @switcher_class
          ])}
        >
          {@checked && "Published" || "Not Published"}
        </span>
      </span>
    </AsComponent>
    """
  end
end
