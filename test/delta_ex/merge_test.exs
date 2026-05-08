defmodule DeltaEx.MergeTest do
  use ExUnit.Case, async: true
  alias DeltaEx

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "delta_ex_merge_test_#{:erlang.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "non-existent resources" do
    test "merge on non-existent path returns error", %{tmp_dir: tmp_dir} do
      missing = Path.join(tmp_dir, "missing")
      assert {:error, _} = DeltaEx.merge(missing, [%{id: 1}], "target.id = source.id")
    end
  end

  describe "input validation" do
    test "raises when uri is not a binary" do
      assert_raise FunctionClauseError, fn -> DeltaEx.merge(123, [%{id: 1}], "t.id = s.id") end
    end

    test "raises when data is not a list", %{tmp_dir: tmp_dir} do
      assert_raise FunctionClauseError, fn ->
        DeltaEx.merge(tmp_dir, %{id: 1}, "t.id = s.id")
      end
    end

    test "raises when predicate is not a binary", %{tmp_dir: tmp_dir} do
      assert_raise FunctionClauseError, fn -> DeltaEx.merge(tmp_dir, [%{id: 1}], nil) end
    end
  end

  test "merge accepts mixed atom and string keys", %{tmp_dir: tmp_dir} do
    :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice", age: 30}])

    merge_data = [
      %{:id => 1, "name" => "Alice Updated", :age => 31},
      %{"id" => 2, :name => "Bob", "age" => 25}
    ]

    :ok = DeltaEx.merge(tmp_dir, merge_data, "target.id = source.id")

    {:ok, table} = DeltaEx.load_table(tmp_dir)
    result = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

    assert result == [
             %{"id" => 1, "name" => "Alice Updated", "age" => 31},
             %{"id" => 2, "name" => "Bob", "age" => 25}
           ]
  end

  test "merge (upsert) data into a table", %{tmp_dir: tmp_dir} do
    # 1. Create initial table
    initial_data = [
      %{id: 1, name: "Alice", age: 30},
      %{id: 2, name: "Bob", age: 25}
    ]

    :ok = DeltaEx.insert(tmp_dir, initial_data)

    # 2. Prepare merge data
    merge_data = [
      # Update
      %{id: 2, name: "Bob Updated", age: 26},
      # Insert
      %{id: 3, name: "Charlie", age: 20}
    ]

    # 3. Perform merge
    :ok = DeltaEx.merge(tmp_dir, merge_data, "target.id = source.id")

    # 4. Verify results
    {:ok, table} = DeltaEx.load_table(tmp_dir)
    result = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

    assert result == [
             %{"id" => 1, "name" => "Alice", "age" => 30},
             %{"id" => 2, "name" => "Bob Updated", "age" => 26},
             %{"id" => 3, "name" => "Charlie", "age" => 20}
           ]
  end
end
