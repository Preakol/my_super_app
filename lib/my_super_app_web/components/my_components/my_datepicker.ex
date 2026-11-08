defmodule MySuperAppWeb.MyDatepicker do
  @moduledoc false

  use Moon.StatefulComponent

  alias Moon.Design.Dropdown
  alias Moon.Components.Chip
  alias Moon.Icons.MailFilterCrossed

  import Date, only: [new: 3, day_of_week: 1, add: 2]

  prop(start_date, :date, required: true)
  prop(end_date, :date, required: true)
  prop(on_change, :event, from_context: :on_change, required: true)
  prop(panel_class, :css_class, from_context: :class)
  prop(button_class, :css_class, from_context: :class)

  data(month, :date, default: Date.utc_today())
  data(is_open, :boolean, default: false)

  def handle_event("change_month", %{"value" => value}, socket) do
    {:noreply, assign(socket, month: Date.from_iso8601!(value), is_open: true)}
  end

  def handle_event("on_trigger", _, socket) do
    {:noreply, assign(socket, is_open: !socket.assigns.is_open)}
  end

  defp month_weeks(date) do
    {:ok, month_start} = new(date.year, date.month, 1)
    start = month_start |> add(1 - day_of_week(month_start))

    0..4
    |> Enum.to_list
    |> Enum.map(fn week_nr ->
      0..6
      |> Enum.to_list
      |> Enum.map(&add(start, week_nr * 7 + &1))
    end)
  end

  defp months() do
    [""] ++ ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  end

  def render(assigns) do
    ~F"""
    <div class="flex">
      <Dropdown id="dropdown-datepicker" {=@is_open} on_trigger="on_trigger">
        <Dropdown.Trigger>
          <Chip
            class={merge(["border border-bulma rounded-none sm:rounded-l-xl whitespace-nowrap text-bulma bg-goku hover:text-goku hover:bg-bulma", @button_class])}
          >{@start_date && "Start: #{@start_date} | End: #{@end_date || "YYYY-MM-DD"}" || "Choose date range..."}</Chip>
        </Dropdown.Trigger>
        <Dropdown.Options class={merge(["w-auto p-1", @panel_class])} {=@is_open}>
          <div class="w-full flex justify-between">
            <button class="hover:bg-gohan rounded-moon-i-sm py-1 w-6" :on-click="change_month" value={add(@month, -30)}> {"<"} </button>
            <span class="py-1">{Enum.at(months(), @month.month)} {@month.year}</span>
            <button class="hover:bg-gohan rounded-moon-i-sm py-1 w-6" :on-click="change_month" value={add(@month, 30)}> {">"} </button>
          </div>
          <div class="py-1 flex">
            {#for day <- ~w(m t w t f s s)}
              <span class="w-6 bg-gohan inline-block uppercase text-center">{day}</span>
            {/for}
          </div>
          {#for week <- month_weeks(@month)}
            <div class="py-1 flex">
              {#for day <- week}
                <button class={
                  "w-6 hover:bg-bulma hover:text-goku rounded-moon-i-sm",
                  "font-medium bg-krillin": @start_date == "#{day}" || @end_date == "#{day}",
                  "text-trunks": day.month != @month.month,
                  "bg-krillin-60": @start_date && @end_date && @start_date < "#{day}" && @end_date > "#{day}",
                  "text-piccolo": day == Date.utc_today()
                } value={day} :on-click={@on_change}>{day.day}</button>
              {/for}
            </div>
          {/for}
        </Dropdown.Options>
      </Dropdown>
      <Chip on_click={@on_change}
        value={nil}
        class="border border-bulma rounded-none sm:rounded-r-xl text-bulma bg-goku hover:text-goku hover:bg-bulma"
      >
        <MailFilterCrossed class="text-moon-24" />
      </Chip>
    </div>
    """
  end
end
