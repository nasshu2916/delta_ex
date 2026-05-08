defmodule DeltaEx.ConfigTest do
  # async: false because tests mutate Application env for :delta_ex.
  use ExUnit.Case, async: false

  alias DeltaEx.Config

  setup do
    previous =
      for key <- [:keys, :storage_options, :writer, :vacuum, :query] do
        {key, Application.get_env(:delta_ex, key)}
      end

    on_exit(fn ->
      for {key, value} <- previous do
        case value do
          nil -> Application.delete_env(:delta_ex, key)
          v -> Application.put_env(:delta_ex, key, v)
        end
      end
    end)

    :ok
  end

  describe "keys/0" do
    test "defaults to :strings" do
      Application.delete_env(:delta_ex, :keys)
      assert Config.keys() == :strings
    end

    test "returns the configured value" do
      Application.put_env(:delta_ex, :keys, :atoms)
      assert Config.keys() == :atoms
    end

    test "raises on an invalid value" do
      Application.put_env(:delta_ex, :keys, :bogus)
      assert_raise ArgumentError, fn -> Config.keys() end
    end
  end

  describe "storage_options/0" do
    test "defaults to nil" do
      Application.delete_env(:delta_ex, :storage_options)
      assert Config.storage_options() == nil
    end

    test "treats an empty map as nil" do
      Application.put_env(:delta_ex, :storage_options, %{})
      assert Config.storage_options() == nil
    end

    test "stringifies keys and values" do
      Application.put_env(:delta_ex, :storage_options, %{region: :ap_northeast_1})
      assert Config.storage_options() == %{"region" => "ap_northeast_1"}
    end

    test "raises on a non-map value" do
      Application.put_env(:delta_ex, :storage_options, "oops")
      assert_raise ArgumentError, fn -> Config.storage_options() end
    end
  end

  describe "writer/0, vacuum/0, query/0" do
    test "default to []" do
      for key <- [:writer, :vacuum, :query] do
        Application.delete_env(:delta_ex, key)
      end

      assert Config.writer() == []
      assert Config.vacuum() == []
      assert Config.query() == []
    end

    test "return the configured keyword list" do
      Application.put_env(:delta_ex, :writer, target_file_size: 1024)
      Application.put_env(:delta_ex, :vacuum, retention_hours: 24, dry_run: false)
      Application.put_env(:delta_ex, :query, table_name: "users")

      assert Config.writer() == [target_file_size: 1024]
      assert Config.vacuum() == [retention_hours: 24, dry_run: false]
      assert Config.query() == [table_name: "users"]
    end

    test "raise when the value is not a keyword list" do
      Application.put_env(:delta_ex, :writer, %{target_file_size: 1024})
      assert_raise ArgumentError, fn -> Config.writer() end
    end
  end

  describe "integration with reader/writer/query" do
    @describetag :tmp_dir

    test "default :keys mode applies to to_list/2", %{tmp_dir: tmp_dir} do
      Application.put_env(:delta_ex, :keys, :atoms)

      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "Alice"}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert [%{id: 1, name: "Alice"}] = DeltaEx.to_list(table)
    end

    test "per-call :keys overrides the configured default", %{tmp_dir: tmp_dir} do
      Application.put_env(:delta_ex, :keys, :atoms)

      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert [%{"id" => 1}] = DeltaEx.to_list(table, keys: :strings)
    end

    test "default :query.table_name applies", %{tmp_dir: tmp_dir} do
      Application.put_env(:delta_ex, :query, table_name: "users")

      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}, %{id: 2}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert {:ok, [%{"c" => 2}]} =
               DeltaEx.query(table, "SELECT count(*) AS c FROM users")
    end

    test "default writer options reach insert/3", %{tmp_dir: tmp_dir} do
      Application.put_env(:delta_ex, :writer,
        target_file_size: 1_048_576,
        write_batch_size: 1024
      )

      assert :ok = DeltaEx.insert(tmp_dir, [%{id: 1}, %{id: 2}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert length(DeltaEx.to_list(table)) == 2
    end
  end
end
