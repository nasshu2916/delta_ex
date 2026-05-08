defmodule DeltaEx.WriterTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "insert/2" do
    test "creates a new table and inserts data", %{tmp_dir: tmp_dir} do
      data = [%{id: 1, val: "a"}]
      assert :ok = DeltaEx.insert(tmp_dir, data)
      assert File.exists?("#{tmp_dir}/_delta_log")
    end

    test "appends data to an existing table", %{tmp_dir: tmp_dir} do
      data1 = [%{id: 1, val: "a"}]
      data2 = [%{id: 2, val: "b"}]

      assert :ok = DeltaEx.insert(tmp_dir, data1)
      assert :ok = DeltaEx.insert(tmp_dir, data2)

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      results = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])
      assert results == [%{"id" => 1, "val" => "a"}, %{"id" => 2, "val" => "b"}]
    end

    test "version increments after each append", %{tmp_dir: tmp_dir} do
      assert :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, t0} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.version(t0) == 0

      assert :ok = DeltaEx.insert(tmp_dir, [%{id: 2}])
      {:ok, t1} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.version(t1) == 1
    end

    test "returns error for empty data", %{tmp_dir: tmp_dir} do
      assert {:error, "Empty data"} = DeltaEx.insert(tmp_dir, [])
    end

    test "supports various data types", %{tmp_dir: tmp_dir} do
      data = [
        %{
          int: 42,
          float: 3.14,
          bool: true,
          string: "hello",
          nil_val: nil
        }
      ]

      assert :ok = DeltaEx.insert(tmp_dir, data)

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert [
               %{
                 "int" => 42,
                 "bool" => true,
                 "string" => "hello",
                 "nil_val" => nil,
                 "float" => float
               }
             ] = DeltaEx.to_list(table)

      assert_in_delta float, 3.14, 0.001
    end
  end

  describe "insert/3 with options" do
    test "accepts :app_metadata and persists it in the commit log", %{tmp_dir: tmp_dir} do
      assert :ok =
               DeltaEx.insert(tmp_dir, [%{id: 1}],
                 app_metadata: %{"job" => "etl", "run_id" => "abc"}
               )

      log_file = Path.join([tmp_dir, "_delta_log", "00000000000000000000.json"])
      contents = File.read!(log_file)
      assert contents =~ ~s("job":"etl")
      assert contents =~ ~s("run_id":"abc")
    end

    test "accepts :target_file_size and :write_batch_size", %{tmp_dir: tmp_dir} do
      assert :ok =
               DeltaEx.insert(tmp_dir, [%{id: 1}, %{id: 2}],
                 target_file_size: 1_048_576,
                 write_batch_size: 1024
               )

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert length(DeltaEx.to_list(table)) == 2
    end
  end

  describe "key types" do
    test "accepts mixed atom and string keys across rows", %{tmp_dir: tmp_dir} do
      data = [
        %{id: 1, val: "a"},
        %{"id" => 2, "val" => "b"}
      ]

      assert :ok = DeltaEx.insert(tmp_dir, data)

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      results = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])
      assert results == [%{"id" => 1, "val" => "a"}, %{"id" => 2, "val" => "b"}]
    end
  end

  describe "input validation" do
    test "raises when uri is not a binary" do
      assert_raise FunctionClauseError, fn -> DeltaEx.insert(123, [%{id: 1}]) end
    end

    test "raises when data is not a list", %{tmp_dir: tmp_dir} do
      assert_raise FunctionClauseError, fn -> DeltaEx.insert(tmp_dir, %{id: 1}) end
      assert_raise FunctionClauseError, fn -> DeltaEx.insert(tmp_dir, nil) end
    end

    test "raises when uri is nil" do
      assert_raise FunctionClauseError, fn -> DeltaEx.insert(nil, [%{id: 1}]) end
    end
  end

  describe "edge cases" do
    test "inserting into a path with spaces", %{tmp_dir: tmp_dir} do
      uri = Path.join(tmp_dir, "path with spaces")
      data = [%{id: 1}]
      assert :ok = DeltaEx.insert(uri, data)
      {:ok, table} = DeltaEx.load_table(uri)
      results = DeltaEx.to_list(table)
      assert results == [%{"id" => 1}]
    end

    test "inserting with missing fields (nulls) in a single batch", %{tmp_dir: tmp_dir} do
      data = [
        %{id: 1, val: "a"},
        %{id: 2, val: nil}
      ]

      assert :ok = DeltaEx.insert(tmp_dir, data)

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      results = DeltaEx.to_list(table) |> Enum.sort_by(& &1["id"])

      assert results == [
               %{"id" => 1, "val" => "a"},
               %{"id" => 2, "val" => nil}
             ]
    end
  end
end
