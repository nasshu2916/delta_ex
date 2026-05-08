defmodule DeltaEx.ReaderTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "load_table/2" do
    test "returns error for non-existent path" do
      assert {:error, _reason} = DeltaEx.load_table("non_existent_path")
    end

    test "returns error for non-existent table directory", %{tmp_dir: tmp_dir} do
      assert {:error, _} = DeltaEx.load_table(Path.join(tmp_dir, "not_here"))
    end

    test "loads specific version (time travel)", %{tmp_dir: tmp_dir} do
      DeltaEx.insert(tmp_dir, [%{id: 1}])
      DeltaEx.insert(tmp_dir, [%{id: 2}])

      {:ok, table_v0} = DeltaEx.load_table(tmp_dir, version: 0)
      assert DeltaEx.version(table_v0) == 0
      assert DeltaEx.to_list(table_v0) == [%{"id" => 1}]

      {:ok, table_v1} = DeltaEx.load_table(tmp_dir, version: 1)
      assert DeltaEx.version(table_v1) == 1
      results = DeltaEx.to_list(table_v1) |> Enum.sort_by(& &1["id"])
      assert results == [%{"id" => 1}, %{"id" => 2}]
    end

    test "returns error for non-existent version", %{tmp_dir: tmp_dir} do
      DeltaEx.insert(tmp_dir, [%{id: 1}])
      assert {:error, _} = DeltaEx.load_table(tmp_dir, version: 99)
    end
  end

  describe "metadata" do
    setup %{tmp_dir: tmp_dir} do
      DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)
      %{table: table}
    end

    test "version/1 returns the current version", %{table: table} do
      assert DeltaEx.version(table) == 0
    end

    test "files/1 returns the list of data files", %{table: table} do
      files = DeltaEx.files(table)
      assert is_list(files)
      assert Enum.any?(files, fn f -> String.ends_with?(f, ".parquet") end)
    end
  end

  describe "to_list/2" do
    test "reads inserted rows back", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.to_list(table) == [%{"id" => 1, "name" => "Alice"}]
    end

    test "returns atom keys with keys: :atoms", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.to_list(table, keys: :atoms) == [%{id: 1, name: "Alice"}]
    end

    test "returns atom keys with keys: :atoms! when atoms exist", %{tmp_dir: tmp_dir} do
      _ = {:id, :name}
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.to_list(table, keys: :atoms!) == [%{id: 1, name: "Alice"}]
    end

    test "raises ArgumentError on invalid keys option", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert_raise ArgumentError, fn -> DeltaEx.to_list(table, keys: :bogus) end
    end
  end
end
