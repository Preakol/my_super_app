defmodule MySuperApp.SiteConfigManagement do
  @moduledoc """
  The SiteManagement context.
  """

  import Ecto.Query, warn: false
  alias MySuperApp.{Repo, SiteConfig, AdminPubSub}

  def list_potential_brands(), do: Repo.all(from b in "brands", select: b.name)

  def list_site_configs(), do: Repo.all(SiteConfig)

  def list_site_configs_by_date(date) do
    add_date_filter(SiteConfig, date, date)
    |> Repo.all()
  end

  def list_site_configs_by_op(operator_name) do
    from(site in SiteConfig,
      join: operator in assoc(site, :operator),
      where: ilike(operator.name, ^"#{operator_name}%")
    )
    |> Repo.all()
  end

  def list_site_configs_by_filters(%{
        search: search,
        start_date: start_date,
        end_date: end_date,
        sorting: sorting_params
      }) do
    from(
      site in SiteConfig,
      join: operator in assoc(site, :operator),
      select: %{
        id: site.id,
        brand: site.brand,
        status: site.status,
        operator_id: operator.id,
        operator_name: operator.name,
        inserted_at: site.inserted_at
      }
    )
    |> add_search_filter(search)
    |> add_date_filter(start_date, end_date)
    |> add_sorting(sorting_params)
    |> Repo.all()
  end

  def get_site_config(""), do: nil

  def get_site_config(id) do
    Repo.get(SiteConfig, id)
  end

  def create_site_config(attrs \\ %{}) do
    %SiteConfig{}
    |> SiteConfig.changeset(attrs)
    |> Repo.insert()
    |> AdminPubSub.broadcast()
  end

  def update_site_config(id, attrs) do
    Repo.get(SiteConfig, id)
    |> SiteConfig.changeset(attrs)
    |> Repo.update()
    |> AdminPubSub.broadcast()
  end

  def delete_site_config(id) do
    SiteConfig
    |> Repo.get(id)
    |> Repo.delete()
    |> AdminPubSub.broadcast()
  end

  def change_site_config(%SiteConfig{} = site_config, attrs \\ %{}) do
    SiteConfig.changeset(site_config, attrs)
  end

  def get_existing_brands() do
    Repo.all(from site in SiteConfig, select: site.brand)
  end

  defp add_search_filter(query, search) do
    case Integer.parse(search) do
      {number, ""} ->
        from(site in query,
          where: site.id == ^number
        )

      _ ->
        from(site in query,
          join: operator in assoc(site, :operator),
          where:
            ilike(site.brand, ^"#{search}%") or
              ilike(operator.name, ^"#{search}%")
        )
    end
  end

  defp add_date_filter(query, nil, _), do: query

  defp add_date_filter(query, start_date, end_date) do
    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    from(site in query,
      where:
        fragment("date(?)", site.inserted_at) >= ^start_date and
          fragment("date(?)", site.inserted_at) <= ^end_date
    )
  end

  defp add_sorting(query, [{parameter, direction}]) do
    from(site in query,
      order_by: ^[{direction |> String.downcase() |> String.to_atom(), parameter}]
    )
  end
end
