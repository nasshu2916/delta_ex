defmodule DeltaEx.MetadataTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "history/2" do
    test "returns commit info ordered most-recent first", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      :ok = DeltaEx.insert(tmp_dir, [%{id: 2}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, [%{version: 1, operation: operation}, %{version: 0}]} = DeltaEx.history(table)
      assert is_binary(operation)
    end

    test "respects :limit", %{tmp_dir: tmp_dir} do
      Enum.each(1..3, fn i -> DeltaEx.insert(tmp_dir, [%{id: i}]) end)

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, [_]} = DeltaEx.history(table, limit: 1)
    end
  end

  describe "protocol/1" do
    test "returns reader/writer versions", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, %{min_reader_version: reader, min_writer_version: writer}} =
               DeltaEx.protocol(table)

      assert is_integer(reader) and reader >= 1
      assert is_integer(writer) and writer >= 1
    end
  end

  describe "partition_columns/1" do
    test "returns empty list for unpartitioned tables", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, []} = DeltaEx.partition_columns(table)
    end
  end

  describe "file_uris/1" do
    test "returns absolute parquet URIs", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      uris = DeltaEx.file_uris(table)

      assert is_list(uris)
      assert Enum.any?(uris, &String.ends_with?(&1, ".parquet"))
    end
  end

  describe "count/1" do
    test "returns the number of rows from per-file stats", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}, %{id: 2}, %{id: 3}])
      :ok = DeltaEx.insert(tmp_dir, [%{id: 4}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, 4} = DeltaEx.count(table)
    end
  end

  describe "delta_table?/1" do
    test "returns true for a Delta table", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      assert DeltaEx.delta_table?(tmp_dir)
    end

    test "returns false for non-existent path", %{tmp_dir: tmp_dir} do
      refute DeltaEx.delta_table?(Path.join(tmp_dir, "no_such_table"))
    end

    test "returns false for a non-Delta directory", %{tmp_dir: tmp_dir} do
      refute DeltaEx.delta_table?(tmp_dir)
    end
  end

  describe "input validation" do
    test "delta_table?/1 raises when uri is not a binary" do
      assert_raise FunctionClauseError, fn -> DeltaEx.delta_table?(123) end
      assert_raise FunctionClauseError, fn -> DeltaEx.delta_table?(nil) end
    end

    test "set_table_name/2 raises when name is not a binary", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn -> DeltaEx.set_table_name(table, :users) end
    end

    test "set_table_description/2 raises when description is not a binary", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn -> DeltaEx.set_table_description(table, nil) end
    end

    test "set_column_metadata/3 raises when metadata is not a map", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn ->
        DeltaEx.set_column_metadata(table, "id", [{"k", "v"}])
      end
    end

    test "set_table_properties/3 raises when properties is not a map", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn ->
        DeltaEx.set_table_properties(table, [{"k", "v"}])
      end
    end
  end

  describe "set_table_name/2" do
    test "updates the table name", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.set_table_name(table, "users")
    end
  end

  describe "set_table_description/2" do
    test "updates the table description", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.set_table_description(table, "User accounts table")
    end
  end

  describe "set_column_metadata/3" do
    test "sets metadata on an existing column", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert :ok = DeltaEx.set_column_metadata(table, "id", %{description: "primary key"})
    end

    test "returns error for unknown columns", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:error, _} = DeltaEx.set_column_metadata(table, "missing", %{k: "v"})
    end

    test "accepts mixed atom and string keys in metadata map", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert :ok =
               DeltaEx.set_column_metadata(table, "id", %{
                 :description => "primary key",
                 "tag" => "pk"
               })
    end
  end

  describe "set_table_properties/3" do
    test "sets table-level properties", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert :ok =
               DeltaEx.set_table_properties(
                 table,
                 %{"custom.property": "value"},
                 raise_if_not_exists: false
               )
    end

    test "accepts mixed atom and string keys in properties map", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert :ok =
               DeltaEx.set_table_properties(
                 table,
                 %{:custom_prop => "value", "delta.logRetentionDuration" => "interval 7 days"},
                 raise_if_not_exists: false
               )
    end
  end
end
