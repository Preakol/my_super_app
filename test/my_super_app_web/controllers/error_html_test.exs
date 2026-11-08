defmodule MySuperAppWeb.ErrorHTMLTest do
  use MySuperAppWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 500.html" do
    assert render_to_string(MySuperAppWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
