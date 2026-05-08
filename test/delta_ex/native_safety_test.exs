defmodule DeltaEx.NativeSafetyTest do
  @moduledoc """
  NIF 境界の堅牢性テスト。

  Delta テーブルの ResourceArc を期待する NIF に対して、無関係な
  Erlang reference を渡しても BEAM がクラッシュせず ArgumentError で
  安全に弾かれることを保証する。
  """
  use ExUnit.Case, async: true

  describe "table-arity NIFs reject foreign references" do
    setup do
      %{bogus: make_ref()}
    end

    test "version/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.version(ref) end
    end

    test "to_list/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.to_list(ref) end
    end

    test "files/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.files(ref) end
    end

    test "history/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.history(ref) end
    end

    test "count/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.count(ref) end
    end

    test "protocol/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.protocol(ref) end
    end

    test "partition_columns/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.partition_columns(ref) end
    end

    test "file_uris/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.file_uris(ref) end
    end

    test "vacuum/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.vacuum(ref) end
    end

    test "optimize/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.optimize(ref) end
    end

    test "to_arrow_ipc/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.to_arrow_ipc(ref) end
    end

    test "create_checkpoint/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.create_checkpoint(ref) end
    end

    test "deletion_vectors/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.deletion_vectors(ref) end
    end

    test "filesystem_check/1", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.filesystem_check(ref) end
    end

    test "set_table_name/2", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.set_table_name(ref, "foo") end
    end

    test "add_constraint/3", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.add_constraint(ref, "c", "x > 0") end
    end

    test "commit_app_transaction/3", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.commit_app_transaction(ref, "app", 1) end
    end

    test "query/2", %{bogus: ref} do
      assert_raise ArgumentError, fn -> DeltaEx.query(ref, "SELECT 1") end
    end
  end
end
