defmodule PhoenixVite.Manifest do
  defmodule Chunk do
    @type t :: %__MODULE__{
            key: String.t(),
            file: String.t(),
            src: String.t() | nil,
            name: String.t() | nil,
            is_entry?: boolean(),
            is_dynamic_import?: boolean(),
            assets: [String.t()],
            css: [String.t()],
            dynamicImports: [String.t()],
            names: [String.t()],
            imports: [String.t()]
          }
    defstruct [
      :key,
      :file,
      :src,
      :name,
      is_entry?: false,
      is_dynamic_import?: false,
      assets: [],
      css: [],
      dynamicImports: [],
      names: [],
      imports: []
    ]
  end

  def parse(%{} = chunks_map) do
    Map.new(chunks_map, fn {key, chunk} ->
      chunk = %Chunk{
        key: key,
        file: Map.fetch!(chunk, "file"),
        src: Map.get(chunk, "src"),
        name: Map.get(chunk, "name"),
        is_entry?: Map.get(chunk, "isEntry", false),
        is_dynamic_import?: Map.get(chunk, "isDynamicImport", false),
        assets: Map.get(chunk, "assets", []),
        css: Map.get(chunk, "css", []),
        dynamicImports: Map.get(chunk, "dynamicImports", []),
        names: Map.get(chunk, "names", []),
        imports: Map.get(chunk, "imports", [])
      }

      {key, chunk}
    end)
  end

  def parse(json) when is_binary(json) do
    json
    |> JSON.decode!()
    |> parse()
  end

  def parse({app, path}) do
    app
    |> Application.app_dir(path)
    |> File.read!()
    |> parse()
  end

  # https://vite.dev/guide/backend-integration.html
  def imported_chunks(%{} = manifest, name) do
    manifest
    |> Map.fetch!(name)
    |> Map.fetch!(:imports)
    |> walk(manifest, %{})
  end

  defp walk([], _manifest, _seen), do: []

  defp walk([name | rest], manifest, seen) when is_map_key(seen, name) do
    walk(rest, manifest, seen)
  end

  defp walk([name | rest], manifest, seen) do
    chunk = Map.fetch!(manifest, name)
    [chunk | walk(chunk.imports ++ rest, manifest, Map.put(seen, name, true))]
  end

  def cache_static_manifest_latest(%{} = manifest) do
    Map.new(manifest, fn {key, %Chunk{file: file}} -> {key, file} end)
  end
end
