defmodule DeltaEx.FeaturesTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "add_feature enables supported features", %{tmp_dir: tmp_dir} do
    data = [%{id: 1, name: "Alice"}]
    assert :ok = DeltaEx.insert(tmp_dir, data)

    {:ok, table} = DeltaEx.load_table(tmp_dir)

    assert :ok = DeltaEx.add_feature(table, "deletionVectors")
    assert :ok = DeltaEx.add_feature(table, "changeDataFeed")
    assert :ok = DeltaEx.add_feature(table, "v2Checkpoint")

    # Version 0: insert, +1 per add_feature
    assert DeltaEx.version(table) == 3
  end

  test "add_feature returns error for unsupported features", %{tmp_dir: tmp_dir} do
    data = [%{id: 1, name: "Alice"}]
    assert :ok = DeltaEx.insert(tmp_dir, data)

    {:ok, table} = DeltaEx.load_table(tmp_dir)

    assert {:error, reason} = DeltaEx.add_feature(table, "unknownFeature")
    assert reason =~ "Unsupported or unknown feature"
  end

  test "add_feature with atom names", %{tmp_dir: tmp_dir} do
    data = [%{id: 1, name: "Alice"}]
    assert :ok = DeltaEx.insert(tmp_dir, data)

    {:ok, table} = DeltaEx.load_table(tmp_dir)

    assert :ok = DeltaEx.add_feature(table, :deletionVectors)
  end
end
