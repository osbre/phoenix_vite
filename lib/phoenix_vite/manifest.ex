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
    chunk = Map.fetch!(manifest, name)
    imports = chunk.imports

    {chunks, _seen} =
      Enum.reduce(imports, {[], MapSet.new()}, fn name, {acc_files, seen} ->
        {files, seen} = imported_chunks(manifest, name, seen)
        {acc_files ++ files, seen}
      end)

    chunks
  end

  defp imported_chunks(manifest, name, seen) do
    chunk = Map.fetch!(manifest, name)

    if name in seen do
      {[], seen}
    else
      seen = MapSet.put(seen, name)
      imports = chunk.imports

      {chunks, seen} =
        Enum.reduce(imports, {[], seen}, fn name, {acc_chunks, seen} ->
          {chunks, seen} = imported_chunks(manifest, name, seen)
          {acc_chunks ++ chunks, seen}
        end)

      {[chunk | chunks], seen}
    end
  end

  # Chunks reachable through dynamic imports, minus what the entries already load
  def prefetched_files(%{} = manifest, names) do
    names = Enum.map(names, &Path.relative/1)
    loaded = MapSet.new(Enum.flat_map(names, &loaded_files(manifest, &1)))

    names
    |> Enum.flat_map(&Map.fetch!(manifest, &1).dynamicImports)
    |> reachable(manifest, %{})
    |> Enum.flat_map(&[&1.file | &1.css])
    |> Enum.uniq()
    |> Enum.reject(&(&1 in loaded))
  end

  defp reachable([], _manifest, _seen), do: []

  defp reachable([name | rest], manifest, seen) when is_map_key(seen, name) do
    reachable(rest, manifest, seen)
  end

  defp reachable([name | rest], manifest, seen) do
    chunk = Map.fetch!(manifest, name)
    seen = Map.put(seen, name, true)
    [chunk | reachable(chunk.imports ++ chunk.dynamicImports ++ rest, manifest, seen)]
  end

  defp loaded_files(manifest, name) do
    chunk = Map.fetch!(manifest, name)
    Enum.flat_map([chunk | imported_chunks(manifest, name)], &[&1.file | &1.css])
  end

  def cache_static_manifest_latest(%{} = manifest) do
    Map.new(manifest, fn {key, %Chunk{file: file}} -> {key, file} end)
  end
end
