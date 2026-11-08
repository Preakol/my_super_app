defmodule MySuperApp.SiteConfigManagementTest do
  use MySuperApp.DataCase
  alias MySuperApp.{SiteConfigManagement, SiteConfig, Operator, Repo}

  setup do
    Repo.delete_all(SiteConfig)

    operator1 = %Operator{name: "Test Operator1"}
    {:ok, operator1} = Repo.insert(operator1)

    operator2 = %Operator{name: "Test Operator2"}
    {:ok, operator2} = Repo.insert(operator2)

    site_config1 = %SiteConfig{
      brand: "Brand1",
      status: true,
      operator_id: operator1.id,
      inserted_at: ~U[2024-10-01 00:00:00Z]
    }

    site_config2 = %SiteConfig{
      brand: "Brand2",
      status: false,
      operator_id: operator2.id,
      inserted_at: ~U[2024-10-02 00:00:00Z]
    }

    site_config3 = %SiteConfig{
      brand: "Another Brand",
      status: false,
      operator_id: operator2.id,
      inserted_at: ~U[2024-10-03 00:00:00Z]
    }

    {:ok, site_config1} = Repo.insert(site_config1)
    {:ok, site_config2} = Repo.insert(site_config2)
    {:ok, site_config3} = Repo.insert(site_config3)

    {:ok,
     operator1: operator1,
     operator2: operator2,
     site_config1: site_config1,
     site_config2: site_config2,
     site_config3: site_config3}
  end

  describe "list_site_configs_by_filters/1" do
    test "returns all site configs when default filters applied", %{
      site_config1: site_config1,
      site_config2: site_config2,
      site_config3: site_config3
    } do
      result =
        SiteConfigManagement.list_site_configs_by_filters(%{
          search: "",
          start_date: nil,
          end_date: nil,
          sorting: [id: "ASC"]
        })

      assert Enum.map(result, & &1.id) == [site_config1.id, site_config2.id, site_config3.id]
    end

    test "filters by search (brand) correctly", %{
      site_config1: site_config1,
      site_config2: site_config2
    } do
      result =
        SiteConfigManagement.list_site_configs_by_filters(%{
          search: "Brand",
          start_date: nil,
          end_date: nil,
          sorting: [id: "ASC"]
        })

      assert Enum.map(result, & &1.id) == [site_config1.id, site_config2.id]
    end

    test "filters by search (operator name) correctly", %{site_config1: site_config1} do
      result =
        SiteConfigManagement.list_site_configs_by_filters(%{
          search: "Test Operator1",
          start_date: nil,
          end_date: nil,
          sorting: [id: "ASC"]
        })

      assert Enum.map(result, & &1.id) == [site_config1.id]
    end

    test "filters by date range", %{site_config2: site_config2, site_config3: site_config3} do
      result =
        SiteConfigManagement.list_site_configs_by_filters(%{
          search: "",
          start_date: "2024-10-02",
          end_date: "2024-10-03",
          sorting: [id: "ASC"]
        })

      assert Enum.map(result, & &1.id) == [site_config2.id, site_config3.id]
    end

    test "sorts results by inserted_at in descending order", %{
      site_config1: site_config1,
      site_config2: site_config2,
      site_config3: site_config3
    } do
      result =
        SiteConfigManagement.list_site_configs_by_filters(%{
          search: "",
          start_date: nil,
          end_date: nil,
          sorting: [{:inserted_at, "DESC"}]
        })

      assert Enum.map(result, & &1.id) == [site_config3.id, site_config2.id, site_config1.id]
    end
  end

  describe "get_site_config/1" do
    test "returns nil for an empty string ID" do
      assert SiteConfigManagement.get_site_config("") == nil
    end

    test "returns the site config for a valid ID", %{site_config1: site_config1} do
      result = SiteConfigManagement.get_site_config(site_config1.id)
      assert result.id == site_config1.id
      assert result.brand == site_config1.brand
    end
  end

  describe "create_site_config/1" do
    test "creates a new site config", %{operator1: operator1} do
      attrs = %{brand: "New Brand", status: true, operator_id: operator1.id}

      assert {:ok, %SiteConfig{brand: "New Brand"}} =
               SiteConfigManagement.create_site_config(attrs)
    end
  end

  describe "update_site_config/2" do
    test "updates an existing site config", %{site_config1: site_config1} do
      attrs = %{brand: "Updated Brand"}

      assert {:ok, %SiteConfig{brand: "Updated Brand"}} =
               SiteConfigManagement.update_site_config(site_config1.id, attrs)
    end
  end

  describe "delete_site_config/1" do
    test "deletes a site config", %{site_config1: site_config1} do
      assert {:ok, %SiteConfig{}} = SiteConfigManagement.delete_site_config(site_config1.id)
      assert SiteConfigManagement.get_site_config(site_config1.id) == nil
    end
  end

  describe "change_site_config/1" do
    test "returns a changeset for a new site config" do
      attrs = %{brand: "New Brand", status: true, operator_id: 1}
      changeset = SiteConfigManagement.change_site_config(%SiteConfig{}, attrs)
      assert changeset.valid?
    end
  end

  describe "get_existing_brands/0" do
    test "returns a list of existing brands" do
      result = SiteConfigManagement.get_existing_brands()
      assert Enum.member?(result, "Brand1")
      assert Enum.member?(result, "Brand2")
      assert !Enum.member?(result, "Brand3")
    end
  end
end
