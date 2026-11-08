defmodule MySuperApp.Cloudinary.ClientTest do
  use ExUnit.Case, async: true

  alias MySuperApp.Cloudinary.Client

  doctest Client
  doctest MySuperApp.Cloudinary

  @image "test/support/uploads/test_image.jpg"

  describe "upload/2" do
    test "sends a signed multipart request and returns the delivery URL" do
      Req.Test.stub(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1_1/test-cloud/image/upload"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ ~s(name="api_key")
        assert body =~ "test-api-key"
        assert body =~ ~s(name="signature")
        assert body =~ ~s(name="file")
        refute body =~ "test-api-secret"

        Req.Test.json(conn, %{
          "secure_url" => "https://res.cloudinary.com/test-cloud/image/upload/v1/test/a.jpg",
          "public_id" => "test/a"
        })
      end)

      assert {:ok,
              %{
                url: "https://res.cloudinary.com/test-cloud/image/upload/v1/test/a.jpg",
                public_id: "test/a"
              }} =
               Client.upload(@image, folder: "test", public_id: "a")
    end

    test "returns an http error for non-200 responses" do
      Req.Test.stub(Client, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid Signature"}})
      end)

      assert {:error, {:http_error, 401, %{"error" => _}}} = Client.upload(@image, folder: "test")
    end

    test "returns a transport error when Cloudinary is unreachable" do
      Req.Test.stub(Client, &Req.Test.transport_error(&1, :econnrefused))

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               Client.upload(@image, folder: "test")
    end
  end

  describe "delete/1" do
    test "returns :ok when Cloudinary confirms the deletion" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/v1_1/test-cloud/image/destroy"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"public_id" => "test/a", "signature" => _} = URI.decode_query(body)

        Req.Test.json(conn, %{"result" => "ok"})
      end)

      assert :ok = Client.delete("test/a")
    end

    test "reports a missing image" do
      Req.Test.stub(Client, &Req.Test.json(&1, %{"result" => "not found"}))

      assert {:error, :not_found} = Client.delete("test/missing")
    end
  end

  describe "without credentials" do
    setup do
      original = Application.fetch_env!(:my_super_app, Client)
      Application.put_env(:my_super_app, Client, Keyword.put(original, :secret, nil))
      on_exit(fn -> Application.put_env(:my_super_app, Client, original) end)
    end

    test "refuses to call the API" do
      assert {:error, {:not_configured, [:secret]}} = Client.upload(@image, folder: "test")
      assert {:error, {:not_configured, [:secret]}} = Client.delete("test/a")
    end
  end
end
