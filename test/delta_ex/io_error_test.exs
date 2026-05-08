defmodule DeltaEx.IoErrorTest do
  @moduledoc """
  ファイルシステムの権限エラーや書き込み不能パスに対して、
  NIF が BEAM をクラッシュさせず `{:error, _}` を返すことを確認する。
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    on_exit(fn ->
      _ = File.chmod(tmp_dir, 0o700)
    end)

    :ok
  end

  describe "permission errors" do
    @tag :skip_on_root
    test "insert into a read-only existing table returns error", %{tmp_dir: tmp_dir} do
      table = Path.join(tmp_dir, "table")
      :ok = DeltaEx.insert(table, [%{id: 1}])

      File.chmod!(table, 0o500)
      on_exit(fn -> _ = File.chmod(table, 0o700) end)

      assert {:error, reason} = DeltaEx.insert(table, [%{id: 2}])
      assert reason =~ ~r/permission denied|os error 13/i
    end

    @tag :skip_on_root
    test "insert into a read-only parent directory returns error", %{tmp_dir: tmp_dir} do
      File.chmod!(tmp_dir, 0o500)

      assert {:error, _} = DeltaEx.insert(Path.join(tmp_dir, "new_table"), [%{id: 1}])
    end

    @tag :skip_on_root
    test "load_table on read-only directory still discovers a table when log is readable",
         %{tmp_dir: tmp_dir} do
      table = Path.join(tmp_dir, "table")
      :ok = DeltaEx.insert(table, [%{id: 1}])

      File.chmod!(table, 0o500)
      on_exit(fn -> _ = File.chmod(table, 0o700) end)

      # 読み取りは可能であることを確認（権限制限が読み取り経路を壊していない）
      assert {:ok, t} = DeltaEx.load_table(table)
      assert DeltaEx.to_list(t) == [%{"id" => 1}]
    end
  end

  describe "non-writable URIs" do
    test "insert into a path with a NUL byte returns error or raises", %{tmp_dir: tmp_dir} do
      uri = tmp_dir <> "/bad\0path"

      result =
        try do
          DeltaEx.insert(uri, [%{id: 1}])
        rescue
          e -> {:raised, e}
        end

      assert match?({:error, _}, result) or match?({:raised, _}, result)
    end
  end
end
