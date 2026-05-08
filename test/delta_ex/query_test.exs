defmodule DeltaEx.QueryTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "query/3" do
    test "executes SELECT against the registered table", %{tmp_dir: tmp_dir} do
      :ok =
        DeltaEx.insert(tmp_dir, [
          %{id: 1, name: "Alice"},
          %{id: 2, name: "Bob"},
          %{id: 3, name: "Carol"}
        ])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, rows} = DeltaEx.query(table, "SELECT name FROM t WHERE id > 1 ORDER BY id")
      assert Enum.map(rows, & &1["name"]) == ["Bob", "Carol"]
    end

    test "supports a custom :table_name", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}, %{id: 2}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, [%{"c" => 2}]} =
               DeltaEx.query(table, "SELECT count(*) AS c FROM users", table_name: "users")
    end

    test "returns atom keys with keys: :atoms", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, [%{id: 1, name: "Alice"}]} =
               DeltaEx.query(table, "SELECT id, name FROM t", keys: :atoms)
    end

    test "raises when sql is not a binary", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert_raise FunctionClauseError, fn -> DeltaEx.query(table, nil) end
      assert_raise FunctionClauseError, fn -> DeltaEx.query(table, :select_all) end
    end

    test "raises ArgumentError on invalid :keys option", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise ArgumentError, fn ->
        DeltaEx.query(table, "SELECT id FROM t", keys: :bogus)
      end
    end

    test "returns an error for invalid SQL", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:error, _} = DeltaEx.query(table, "NOT VALID SQL")
    end
  end
end
