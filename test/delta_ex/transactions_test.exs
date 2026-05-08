defmodule DeltaEx.TransactionsTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "commit_app_transaction/3 + app_transaction_version/2" do
    test "records and reads back the latest application transaction version", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, nil} = DeltaEx.app_transaction_version(table, "etl-job")

      :ok = DeltaEx.commit_app_transaction(table, "etl-job", 1)
      assert {:ok, 1} = DeltaEx.app_transaction_version(table, "etl-job")

      :ok = DeltaEx.commit_app_transaction(table, "etl-job", 2)
      assert {:ok, 2} = DeltaEx.app_transaction_version(table, "etl-job")
    end

    test "tracks distinct app_ids independently", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      :ok = DeltaEx.commit_app_transaction(table, "job-a", 5)
      :ok = DeltaEx.commit_app_transaction(table, "job-b", 9)

      assert {:ok, 5} = DeltaEx.app_transaction_version(table, "job-a")
      assert {:ok, 9} = DeltaEx.app_transaction_version(table, "job-b")
      assert {:ok, nil} = DeltaEx.app_transaction_version(table, "job-c")
    end
  end

  describe "input validation" do
    test "commit_app_transaction/3 raises when version is not an integer", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn ->
        DeltaEx.commit_app_transaction(table, "etl", "1")
      end
    end

    test "commit_app_transaction/3 raises when app_id is not a binary", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn ->
        DeltaEx.commit_app_transaction(table, :etl, 1)
      end
    end

    test "app_transaction_version/2 raises when app_id is not a binary", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      {:ok, table} = DeltaEx.load_table(tmp_dir)

      assert_raise FunctionClauseError, fn ->
        DeltaEx.app_transaction_version(table, :etl)
      end
    end
  end

  describe "insert/3 with :app_transaction" do
    test "writes data and records an app transaction in the same commit", %{tmp_dir: tmp_dir} do
      :ok =
        DeltaEx.insert(tmp_dir, [%{id: 1}], app_transaction: {"streaming-app", 42})

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, 42} = DeltaEx.app_transaction_version(table, "streaming-app")
    end
  end
end
