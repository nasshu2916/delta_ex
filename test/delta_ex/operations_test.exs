defmodule DeltaEx.OperationsTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "delete/2" do
    test "delete data from a table using a predicate", %{tmp_dir: tmp_dir} do
      initial_data = [
        %{id: 1, name: "Alice", age: 30},
        %{id: 2, name: "Bob", age: 25},
        %{id: 3, name: "Charlie", age: 20}
      ]

      :ok = DeltaEx.insert(tmp_dir, initial_data)
      :ok = DeltaEx.delete(tmp_dir, "id = 2")

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      result = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

      assert result == [
               %{"id" => 1, "name" => "Alice", "age" => 30},
               %{"id" => 3, "name" => "Charlie", "age" => 20}
             ]
    end

    test "delete multiple rows with a predicate", %{tmp_dir: tmp_dir} do
      initial_data = [
        %{id: 1, name: "Alice", age: 30},
        %{id: 2, name: "Bob", age: 25},
        %{id: 3, name: "Charlie", age: 20}
      ]

      :ok = DeltaEx.insert(tmp_dir, initial_data)
      :ok = DeltaEx.delete(tmp_dir, "age > 20")

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      result = DeltaEx.to_list(table)

      assert result == [%{"id" => 3, "name" => "Charlie", "age" => 20}]
    end
  end

  describe "update/3" do
    test "update data in a table", %{tmp_dir: tmp_dir} do
      initial_data = [
        %{id: 1, name: "Alice", age: 30},
        %{id: 2, name: "Bob", age: 25},
        %{id: 3, name: "Charlie", age: 35}
      ]

      :ok = DeltaEx.insert(tmp_dir, initial_data)
      :ok = DeltaEx.update(tmp_dir, %{age: "age + 1"}, "id > 0")
      :ok = DeltaEx.update(tmp_dir, %{name: "'Alice Updated'"}, "id = 1")

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      results = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

      assert results == [
               %{"id" => 1, "name" => "Alice Updated", "age" => 31},
               %{"id" => 2, "name" => "Bob", "age" => 26},
               %{"id" => 3, "name" => "Charlie", "age" => 36}
             ]
    end

    test "update without predicate (updates all rows)", %{tmp_dir: tmp_dir} do
      initial_data = [
        %{id: 1, status: "inactive"},
        %{id: 2, status: "inactive"}
      ]

      :ok = DeltaEx.insert(tmp_dir, initial_data)
      :ok = DeltaEx.update(tmp_dir, %{status: "'active'"})

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      results = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

      assert results == [
               %{"id" => 1, "status" => "active"},
               %{"id" => 2, "status" => "active"}
             ]
    end

    test "accepts mixed atom and string keys in updates map", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, status: "inactive", name: "Alice"}])

      :ok =
        DeltaEx.update(
          tmp_dir,
          %{:status => "'active'", "name" => "'Bob'"},
          "id = 1"
        )

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.to_list(table) == [%{"id" => 1, "status" => "active", "name" => "Bob"}]
    end
  end

  describe "vacuum/2" do
    setup %{tmp_dir: tmp_dir} do
      DeltaEx.insert(tmp_dir, [%{id: 1}])
      DeltaEx.insert(tmp_dir, [%{id: 2}])
      DeltaEx.insert(tmp_dir, [%{id: 3}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)
      %{table: table}
    end

    test "default options (vacuum/1) returns a list", %{table: table} do
      assert deleted = DeltaEx.vacuum(table)
      assert is_list(deleted)
    end

    test "dry run returns a list", %{table: table} do
      assert deleted = DeltaEx.vacuum(table, dry_run: true)
      assert is_list(deleted)
    end

    test "accepts retention_hours option", %{table: table} do
      assert deleted = DeltaEx.vacuum(table, retention_hours: 169, dry_run: true)
      assert is_list(deleted)
    end
  end

  describe "optimize/2" do
    test "compacts files (optimize/1)", %{tmp_dir: tmp_dir} do
      DeltaEx.insert(tmp_dir, [%{id: 1}])
      DeltaEx.insert(tmp_dir, [%{id: 2}])
      DeltaEx.insert(tmp_dir, [%{id: 3}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.optimize(table)
    end

    test "z_order clusters on the given columns", %{tmp_dir: tmp_dir} do
      DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])
      DeltaEx.insert(tmp_dir, [%{id: 2, name: "Bob"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.optimize(table, z_order: ["id"])
    end
  end

  describe "filesystem_check/1" do
    test "runs successfully", %{tmp_dir: tmp_dir} do
      data = [%{id: 1, name: "Alice"}]
      assert :ok = DeltaEx.insert(tmp_dir, data)

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.filesystem_check(table)
    end
  end

  describe "restore/2" do
    test "restores table to a previous version", %{tmp_dir: tmp_dir} do
      data1 = [%{id: 1, name: "Alice"}]
      assert :ok = DeltaEx.insert(tmp_dir, data1)

      data2 = [%{id: 2, name: "Bob"}]
      assert :ok = DeltaEx.insert(tmp_dir, data2)

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.version(table) == 1
      assert length(DeltaEx.to_list(table)) == 2

      assert :ok = DeltaEx.restore(table, version: 0)
      assert DeltaEx.version(table) == 2
      assert DeltaEx.to_list(table) == [%{"id" => 1, "name" => "Alice"}]
    end

    test "returns error when no version or datetime given (restore/1)", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:error, reason} = DeltaEx.restore(table)
      assert reason =~ ~r/version|datetime/
    end
  end

  describe "convert_to_delta/1" do
    test "converts parquet files to a delta table", %{tmp_dir: tmp_dir} do
      data = [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]

      assert :ok = DeltaEx.insert(tmp_dir, data)
      assert File.exists?("#{tmp_dir}/_delta_log")

      File.rm_rf!("#{tmp_dir}/_delta_log")
      refute File.exists?("#{tmp_dir}/_delta_log")

      assert {:ok, table} = DeltaEx.convert_to_delta(tmp_dir)
      assert File.exists?("#{tmp_dir}/_delta_log")

      results = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

      assert results == [
               %{"id" => 1, "name" => "Alice"},
               %{"id" => 2, "name" => "Bob"}
             ]
    end
  end

  describe "add_column/4" do
    test "adds a new column to the table", %{tmp_dir: tmp_dir} do
      data = [%{id: 1, name: "Alice"}]
      assert :ok = DeltaEx.insert(tmp_dir, data)

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.add_column(table, "age", :integer)

      actual_data = DeltaEx.to_list(table)
      assert [%{"age" => nil, "id" => 1, "name" => "Alice"}] = actual_data

      new_data = [%{age: 30, id: 2, name: "Bob"}]
      assert :ok = DeltaEx.insert(tmp_dir, new_data)

      {:ok, table2} = DeltaEx.load_table(tmp_dir)
      actual_data2 = DeltaEx.to_list(table2) |> Enum.sort_by(& &1["id"])

      assert [
               %{"age" => nil, "id" => 1, "name" => "Alice"},
               %{"age" => 30, "id" => 2, "name" => "Bob"}
             ] == actual_data2
    end

    test "respects nullable: false option (add_column/4)", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.add_column(table, "score", :integer, nullable: false)
    end
  end

  describe "non-existent resources" do
    test "delete/2 on non-existent table returns error", %{tmp_dir: tmp_dir} do
      assert {:error, _} = DeltaEx.delete(Path.join(tmp_dir, "missing"), "id = 1")
    end

    test "update/3 on non-existent table returns error", %{tmp_dir: tmp_dir} do
      assert {:error, _} = DeltaEx.update(Path.join(tmp_dir, "missing"), %{age: "1"}, "id = 1")
    end

    test "convert_to_delta/1 on empty directory returns error", %{tmp_dir: tmp_dir} do
      empty = Path.join(tmp_dir, "empty")
      File.mkdir_p!(empty)
      assert {:error, _} = DeltaEx.convert_to_delta(empty)
    end

    test "convert_to_delta/1 on non-existent path returns error", %{tmp_dir: tmp_dir} do
      assert {:error, _} = DeltaEx.convert_to_delta(Path.join(tmp_dir, "no_such_dir"))
    end
  end

  describe "input validation" do
    test "delete/2 raises when uri is not a binary" do
      assert_raise FunctionClauseError, fn -> DeltaEx.delete(123, "id = 1") end
    end

    test "delete/2 raises when predicate is not a binary", %{tmp_dir: tmp_dir} do
      assert_raise FunctionClauseError, fn -> DeltaEx.delete(tmp_dir, nil) end
      assert_raise FunctionClauseError, fn -> DeltaEx.delete(tmp_dir, :foo) end
    end

    test "update/3 raises when updates is not a map", %{tmp_dir: tmp_dir} do
      assert_raise FunctionClauseError, fn -> DeltaEx.update(tmp_dir, [{:age, "1"}], "id = 1") end
      assert_raise FunctionClauseError, fn -> DeltaEx.update(tmp_dir, nil, "id = 1") end
    end

    test "update/3 raises when predicate is not a binary", %{tmp_dir: tmp_dir} do
      assert_raise FunctionClauseError, fn -> DeltaEx.update(tmp_dir, %{age: "1"}, nil) end
    end
  end

  describe "constraints" do
    test "add and drop check constraints", %{tmp_dir: tmp_dir} do
      data = [%{id: 1, age: 20}]
      assert :ok = DeltaEx.insert(tmp_dir, data)

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert :ok = DeltaEx.add_constraint(table, "valid_age", "age >= 0")

      assert {:error, reason} = DeltaEx.add_constraint(table, "strict_age", "age > 30")
      assert reason =~ "Add Constraint:"

      invalid_data = [%{id: 2, age: -1}]
      assert {:error, insert_reason} = DeltaEx.insert(tmp_dir, invalid_data)
      assert insert_reason =~ ~r/violated|constraint|invariant|check/i

      assert :ok = DeltaEx.drop_constraint(table, "valid_age")

      assert :ok = DeltaEx.insert(tmp_dir, invalid_data)

      {:ok, table2} = DeltaEx.load_table(tmp_dir)
      assert length(DeltaEx.to_list(table2)) == 2
    end
  end
end
