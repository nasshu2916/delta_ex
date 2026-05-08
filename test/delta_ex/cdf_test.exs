defmodule DeltaEx.CdfTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "load_cdf/2" do
    test "returns CDF rows once changeDataFeed is enabled", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      :ok = DeltaEx.add_feature(table, "changeDataFeed")

      :ok =
        DeltaEx.set_table_properties(
          table,
          %{"delta.enableChangeDataFeed" => "true"},
          raise_if_not_exists: false
        )

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      cdf_start = DeltaEx.version(table) + 1

      :ok = DeltaEx.insert(tmp_dir, [%{id: 2, name: "Bob"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, rows} = DeltaEx.load_cdf(table, starting_version: cdf_start)
      assert Enum.any?(rows, &Map.has_key?(&1, "_change_type"))
    end

    test "returns atom keys with keys: :atoms", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      :ok = DeltaEx.add_feature(table, "changeDataFeed")

      :ok =
        DeltaEx.set_table_properties(
          table,
          %{"delta.enableChangeDataFeed" => "true"},
          raise_if_not_exists: false
        )

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      cdf_start = DeltaEx.version(table) + 1

      :ok = DeltaEx.insert(tmp_dir, [%{id: 2, name: "Bob"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, rows} =
               DeltaEx.load_cdf(table, starting_version: cdf_start, keys: :atoms)

      assert Enum.any?(rows, &Map.has_key?(&1, :_change_type))
    end

    test "errors when no starting version or timestamp is provided", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:error, _} = DeltaEx.load_cdf(table, [])
    end
  end
end
