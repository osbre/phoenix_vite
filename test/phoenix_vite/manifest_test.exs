defmodule PhoenixVite.ManifestTest do
  use ExUnit.Case, async: true
  alias PhoenixVite.Manifest

  describe "parse/1" do
    test "with json" do
      json = """
      {
        "js/app.js": {
          "file": "assets/app-C-lebOsX.js",
          "name": "app",
          "src": "js/app.js",
          "isEntry": true,
          "css": [
            "assets/app-BE15pjT4.css"
          ]
        }
      }
      """

      map = Manifest.parse(json)

      assert map_size(map) == 1

      %Manifest.Chunk{} = chunk = Map.fetch!(map, "js/app.js")

      assert chunk.key == "js/app.js"
      assert chunk.file == "assets/app-C-lebOsX.js"
      assert chunk.src == "js/app.js"
      assert chunk.name == "app"
      assert chunk.is_entry? == true
      assert chunk.is_dynamic_import? == false
      assert chunk.assets == []
      assert chunk.css == ["assets/app-BE15pjT4.css"]
      assert chunk.dynamicImports == []
      assert chunk.names == []
      assert chunk.imports == []
    end
  end

  describe "imported_chunks/2" do
    test "works" do
      json = """
      {
        "js/app.js": {
          "file": "assets/app-C-lebOsX.js",
          "name": "app",
          "src": "js/app.js",
          "isEntry": true,
          "css": [
            "assets/app-BE15pjT4.css"
          ]
        }
      }
      """

      manifest = Manifest.parse(json)

      assert [] = Manifest.imported_chunks(manifest, "js/app.js")
    end

    test "with nested imports" do
      manifest =
        Manifest.parse(%{
          "app.js" => %{"file" => "app.js", "imports" => ["_a.js", "_b.js"]},
          "_a.js" => %{"file" => "a.js", "imports" => ["_c.js"]},
          "_b.js" => %{"file" => "b.js", "imports" => ["_c.js", "_a.js"]},
          "_c.js" => %{"file" => "c.js"}
        })

      assert manifest |> Manifest.imported_chunks("app.js") |> Enum.map(& &1.file) ==
               ["a.js", "c.js", "b.js"]
    end
  end
end
