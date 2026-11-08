defmodule MySuperAppWeb.SiteConfigJSON do
  @moduledoc false

  def index(%{site_configs: site_configs}) do
    %{data: for(site_config <- site_configs, do: data(site_config))}
  end

  def show(%{site_config: site_config}) do
    %{data: data(site_config)}
  end

  defp data(%{} = site_config) do
    %{
      id: site_config.id,
      brand: site_config.brand,
      status: site_config.status && "ACTIVE" || "STOPPED",
      operator_id: site_config.operator_id,
      inserted_at: site_config.inserted_at,
      updated_at: site_config.updated_at
    }
  end
end
