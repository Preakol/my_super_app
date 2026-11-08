defmodule MySuperAppWeb.AdminMainPage.Table do
  @moduledoc false
  use Moon.StatelessComponent

  alias Moon.Design.{Table, Table.Column, Button.IconButton}

  # prop(just_viewer, :boolean, required: true)
  prop(current_user, :map, required: true)
  prop(users, :list, required: true)
  prop(sort, :list, required: true)
  prop(sorting_click, :event, from_context: :sorting_click, required: true)
  prop(on_manage_click, :event, from_context: :on_manage_click, required: true)
  prop(on_delete_click, :event, from_context: :on_delete_click, required: true)


  def render(%{current_user: current_user} = assigns) when current_user.permissions < 4 do
    ~F"""
    <Table
      {=@sort}
      items={user <- @users}
      {=@sorting_click}
      row_bg="bg-heles"
      header_row_class="bg-goku"
      row_gap="border-spacing-y-0"
      sorting_icon="arrows_up"
      class="rounded-0"
      selected={@current_user.id}
      selected_bg="bg-trunks"
    >
      <Column name="id" label="#" sortable class="first:rounded-0">
        {user.id}
      </Column>
      <Column name="login" label="Login" sortable>
        {user.login}
      </Column>
      <Column name="email" label="Email" sortable>
        {user.email}
      </Column>
      <Column name="role" label="Role">
        {user.role_name || "-"}
      </Column>
      <Column name="operator" label="Operator">
        {user.operator_name || "-"}
      </Column>
      <Column name="updated_at" label="Last Update" sortable>
        {user.updated_at |> Timex.shift(hours: 3) |> Timex.format!("%b %d, %Y, %H:%M:%S", :strftime)}
      </Column>
      <Column class="last:rounded-0 flex flex-row justify-end">
        {#if ((@current_user.operator_id == user.operator_id || is_nil(user.role_id)) &&
            user.permissions > @current_user.permissions &&
            user.id != @current_user.id) ||
            @current_user.permissions}
          <IconButton
            icon="generic_user_swapping"
            variant="ghost"
            on_click={@on_manage_click}
            value={user.id}
          />
        {/if}
        {#if ((@current_user.operator_id == user.operator_id || is_nil(user.role_id)) &&
            @current_user.permissions < 3 &&
            user.permissions > @current_user.permissions &&
            user.id != @current_user.id) ||
            (@current_user.permissions == 1 &&
              user.permissions != 2)}
          <IconButton icon="generic_delete" on_click={@on_delete_click} value={user.id} values={action: "open"} variant="ghost" />
        {/if}
      </Column>
    </Table>
    """
  end

  def render(assigns) do
    ~F"""
    <Table
      {=@sort}
      items={user <- @users}
      {=@sorting_click}
      row_bg="bg-heles"
      header_row_class="bg-goku"
      row_gap="border-spacing-y-0"
      sorting_icon="arrows_up"
      class="rounded-0"
      selected={@current_user.id}
      selected_bg="bg-trunks"
    >
      <Column name="id" label="#" sortable class="first:rounded-0">
        {user.id}
      </Column>
      <Column name="login" label="Login" sortable>
        {user.login}
      </Column>
      <Column name="email" label="Email" sortable>
        {user.email}
      </Column>
      <Column name="updated_at" label="Last Update" sortable class="last:rounded-0">
        {user.updated_at |> Timex.shift(hours: 3) |> Timex.format!("%b %d, %Y, %H:%M:%S", :strftime)}
      </Column>
    </Table>
    """
  end
end
