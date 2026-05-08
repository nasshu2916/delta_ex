defmodule DeltaEx.MaintenanceTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "create_checkpoint/1" do
    test "writes a checkpoint file under _delta_log", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      :ok = DeltaEx.insert(tmp_dir, [%{id: 2}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.create_checkpoint(table)

      log_dir = Path.join(tmp_dir, "_delta_log")
      checkpoint_files = log_dir |> File.ls!() |> Enum.filter(&String.contains?(&1, "checkpoint"))
      assert checkpoint_files != []
    end
  end

  describe "cleanup_metadata/1" do
    test "returns the number of removed log files", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, n} = DeltaEx.cleanup_metadata(table)
      assert is_integer(n) and n >= 0
    end
  end

  describe "update_incremental/2" do
    test "fast-forwards an existing handle to the latest version", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert DeltaEx.version(table) == 0

      :ok = DeltaEx.insert(tmp_dir, [%{id: 2}])

      assert {:ok, 1} = DeltaEx.update_incremental(table)
      assert DeltaEx.version(table) == 1
    end

    test "respects :max_version", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      :ok = DeltaEx.insert(tmp_dir, [%{id: 2}])
      :ok = DeltaEx.insert(tmp_dir, [%{id: 3}])

      assert {:ok, 1} = DeltaEx.update_incremental(table, max_version: 1)
      assert DeltaEx.version(table) == 1
    end
  end

  describe "compact_logs/2" do
    test "writes a compacted log file covering the requested range", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      :ok = DeltaEx.insert(tmp_dir, [%{id: 2}])
      :ok = DeltaEx.insert(tmp_dir, [%{id: 3}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.compact_logs(table, start_version: 0, end_version: 2)

      log_files = "#{tmp_dir}/_delta_log" |> File.ls!()

      assert Enum.any?(log_files, fn f ->
               String.contains?(f, "compacted") or String.contains?(f, "log_compaction")
             end)
    end

    test "requires :end_version", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise KeyError, fn -> DeltaEx.compact_logs(table) end
    end
  end

  describe "generate_manifest/1" do
    test "creates a _symlink_format_manifest directory", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert :ok = DeltaEx.generate_manifest(table)

      manifest_path = Path.join([tmp_dir, "_symlink_format_manifest", "manifest"])
      assert File.exists?(manifest_path)
    end
  end
end
