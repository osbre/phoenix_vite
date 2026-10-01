defmodule PhoenixVite.ComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias PhoenixVite.{Components, Manifest}

  @manifest Manifest.parse(%{
              "js/app.js" => %{
                "file" => "assets/app-C-lebOsX.js",
                "isEntry" => true,
                "imports" => ["_shared.js"],
                "css" => ["assets/app-Bx2.css"]
              },
              "_shared.js" => %{
                "file" => "assets/shared-Dk2s9.js",
                "css" => ["assets/shared-BE15pjT4.css"]
              }
            })

  defp assets(attrs) do
    render_component(
      &Components.assets/1,
      Keyword.merge([names: ["js/app.js"], manifest: @manifest], attrs)
    )
  end

  describe "assets/1 with nonce" do
    test "sets it on every tag from the manifest, preloads included" do
      html = assets(nonce: "abc")

      assert length(Regex.scan(~r/<(script|link)/, html)) == 4
      assert length(Regex.scan(~r/nonce="abc"/, html)) == 4
    end

    test "sets it on every tag from the dev server" do
      html = assets(names: ["js/app.js", "css/app.css"], dev_server: true, nonce: "abc")

      assert length(Regex.scan(~r/nonce="abc"/, html)) == 3
    end
  end
end
