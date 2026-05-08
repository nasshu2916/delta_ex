defmodule DeltaEx.DeletionVectorsTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "deletion_vectors/1" do
    test "returns an empty list when no deletion vectors exist", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, []} = DeltaEx.deletion_vectors(table)
    end

    test "returns descriptors for files with deletion vectors", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}, %{id: 2}, %{id: 3}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      :ok = DeltaEx.add_feature(table, "deletionVectors")

      :ok =
        DeltaEx.set_table_properties(
          table,
          %{"delta.enableDeletionVectors" => "true"},
          raise_if_not_exists: false
        )

      :ok = DeltaEx.delete(tmp_dir, "id = 2")

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, dvs} = DeltaEx.deletion_vectors(table)

      Enum.each(dvs, fn dv ->
        assert is_binary(dv.path)
        assert is_binary(dv.storage_type)
        assert is_integer(dv.size_in_bytes)
        assert is_integer(dv.cardinality)
      end)
    end
  end
end
