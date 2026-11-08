defmodule MySuperApp.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MySuperApp.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias MySuperApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MySuperApp.DataCase
      import Mox
    end
  end

  setup tags do
    MySuperApp.DataCase.setup_sandbox(tags)
    MySuperApp.DataCase.stub_cloudinary()
    :ok
  end

  @doc """
  Routes Cloudinary calls to an in-memory stub so no test reaches the network.
  Tests that need a specific response override it with `Mox.expect/4`.
  """
  def stub_cloudinary do
    Mox.stub_with(MySuperApp.CloudinaryMock, MySuperApp.CloudinaryStub)
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MySuperApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
