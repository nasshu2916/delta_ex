defmodule DeltaEx.Integration.S3Test do
  # Cloud-storage integration: end-to-end CRUD against an S3-compatible
  # endpoint. Runs only when explicitly opted in via `--include s3` and
  # the configured endpoint is reachable.
  use ExUnit.Case, async: false

  alias DeltaEx.Test.S3Helper

  @moduletag :s3
  @moduletag :integration

  setup_all do
    unless S3Helper.reachable?() do
      raise """
      S3 endpoint is not reachable. Start the bundled MinIO before running:

          docker compose up -d minio minio-setup
      """
    end

    :ok
  end

  setup do
    {:ok, uri: S3Helper.unique_uri("crud"), opts: [storage_options: S3Helper.storage_options()]}
  end

  test "insert creates the table and round-trips through load_table/to_list", %{
    uri: uri,
    opts: opts
  } do
    rows = [%{"id" => 1, "name" => "Alice"}, %{"id" => 2, "name" => "Bob"}]

    assert :ok = DeltaEx.insert(uri, rows, opts)
    assert true == DeltaEx.delta_table?(uri, opts)

    {:ok, table} = DeltaEx.load_table(uri, opts)
    assert DeltaEx.Reader.version(table) == 0

    actual = DeltaEx.Reader.to_list(table) |> Enum.sort_by(& &1["id"])
    assert actual == rows
  end

  test "merge upserts rows using a target.id = source.id predicate", %{uri: uri, opts: opts} do
    :ok = DeltaEx.insert(uri, [%{"id" => 1, "name" => "Alice"}], opts)

    :ok =
      DeltaEx.merge(
        uri,
        [%{"id" => 1, "name" => "Alice Updated"}, %{"id" => 2, "name" => "Bob"}],
        "target.id = source.id",
        opts
      )

    {:ok, table} = DeltaEx.load_table(uri, opts)
    rows = DeltaEx.Reader.to_list(table) |> Enum.sort_by(& &1["id"])

    assert rows == [
             %{"id" => 1, "name" => "Alice Updated"},
             %{"id" => 2, "name" => "Bob"}
           ]
  end

  test "delete and update apply against S3-backed tables", %{uri: uri, opts: opts} do
    :ok =
      DeltaEx.insert(
        uri,
        [
          %{"id" => 1, "name" => "Alice", "age" => 30},
          %{"id" => 2, "name" => "Bob", "age" => 25}
        ],
        opts
      )

    :ok = DeltaEx.update(uri, %{"age" => "age + 1"}, "id = 1", opts)
    :ok = DeltaEx.delete(uri, "id = 2", opts)

    {:ok, table} = DeltaEx.load_table(uri, opts)

    assert [%{"id" => 1, "name" => "Alice", "age" => 31}] =
             DeltaEx.Reader.to_list(table) |> Enum.sort_by(& &1["id"])
  end

  test "delta_table? returns false for a non-existent S3 prefix", %{opts: opts} do
    refute DeltaEx.delta_table?(S3Helper.unique_uri("does-not-exist"), opts)
  end
end
