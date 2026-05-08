defmodule DeltaEx.ArrowTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "to_arrow_ipc/1" do
    test "returns Arrow IPC stream bytes that start with the IPC magic", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1, name: "a"}, %{id: 2, name: "b"}])

      {:ok, table} = DeltaEx.load_table(tmp_dir)

      # Arrow IPC streaming format starts with 0xFFFFFFFF "continuation" marker.
      assert {:ok, <<0xFFFFFFFF::unsigned-little-32, _::binary>>} = DeltaEx.to_arrow_ipc(table)
    end

    test "handles an empty range gracefully", %{tmp_dir: tmp_dir} do
      :ok = DeltaEx.insert(tmp_dir, [%{id: 1}])
      :ok = DeltaEx.delete(tmp_dir, "id = 1")

      {:ok, table} = DeltaEx.load_table(tmp_dir)
      assert {:ok, ipc} = DeltaEx.to_arrow_ipc(table)
      assert is_binary(ipc)
    end
  end
end
