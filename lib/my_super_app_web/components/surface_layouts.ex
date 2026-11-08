defmodule MySuperAppWeb.SurfaceLayouts do
  @moduledoc false
  use MySuperAppWeb, :html

  embed_sface("layouts/admin.sface")
  embed_sface("layouts/main.sface")
end
