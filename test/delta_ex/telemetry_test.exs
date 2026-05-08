defmodule DeltaEx.TelemetryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @moduletag :tmp_dir

  def forward(name, measurements, metadata, parent) do
    send(parent, {:telemetry, name, measurements, metadata})
  end

  setup %{tmp_dir: tmp_dir, test: test} do
    handler_id = "delta_ex-test-#{test}-#{System.unique_integer([:positive])}"
    parent = self()

    events = [
      [:delta_ex, :insert, :start],
      [:delta_ex, :insert, :stop],
      [:delta_ex, :merge, :stop],
      [:delta_ex, :delete, :stop],
      [:delta_ex, :update, :stop],
      [:delta_ex, :load_table, :stop]
    ]

    :telemetry.attach_many(handler_id, events, &__MODULE__.forward/4, parent)

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, uri: tmp_dir}
  end

  test "insert emits :start and :stop with row_count and uri", %{uri: uri} do
    rows = [%{"id" => 1}, %{"id" => 2}]

    assert :ok = DeltaEx.insert(uri, rows)

    assert_receive {:telemetry, [:delta_ex, :insert, :start], start_meas, start_meta}
    assert_receive {:telemetry, [:delta_ex, :insert, :stop], stop_meas, stop_meta}

    assert is_integer(start_meas.system_time)
    assert is_integer(stop_meas.duration) and stop_meas.duration >= 0
    assert start_meta.uri == uri
    assert start_meta.row_count == 2
    assert start_meta.operation == :insert
    assert stop_meta.result == :ok
  end

  test "merge stop event includes predicate and row_count", %{uri: uri} do
    :ok = DeltaEx.insert(uri, [%{"id" => 1, "name" => "Alice"}])

    :ok =
      DeltaEx.merge(
        uri,
        [%{"id" => 1, "name" => "Updated"}, %{"id" => 2, "name" => "Bob"}],
        "target.id = source.id"
      )

    assert_receive {:telemetry, [:delta_ex, :merge, :stop], _, meta}
    assert meta.predicate == "target.id = source.id"
    assert meta.row_count == 2
    assert meta.result == :ok
  end

  test "load_table on a missing path emits :stop with result: :error" do
    assert {:error, _} = DeltaEx.load_table("/nonexistent/delta-ex-telemetry")

    assert_receive {:telemetry, [:delta_ex, :load_table, :stop], _, meta}
    assert meta.result == :error
    assert is_binary(meta.error)
  end

  test "delete and update emit telemetry with predicate", %{uri: uri} do
    :ok = DeltaEx.insert(uri, [%{"id" => 1, "v" => 10}, %{"id" => 2, "v" => 20}])

    :ok = DeltaEx.update(uri, %{"v" => "v + 1"}, "id = 1")
    assert_receive {:telemetry, [:delta_ex, :update, :stop], _, %{predicate: "id = 1"}}

    :ok = DeltaEx.delete(uri, "id = 2")
    assert_receive {:telemetry, [:delta_ex, :delete, :stop], _, %{predicate: "id = 2"}}
  end

  describe "attach_default_logger/1" do
    setup do
      :ok = DeltaEx.Telemetry.attach_default_logger(:info)
      on_exit(fn -> DeltaEx.Telemetry.detach_default_logger() end)
      :ok
    end

    test "logs successful operations at the configured level", %{uri: uri} do
      log =
        capture_log(fn ->
          :ok = DeltaEx.insert(uri, [%{"id" => 1}])
        end)

      assert log =~ "DeltaEx.insert ok in"
      assert log =~ "row_count=1"
    end

    test "logs errors at :error level" do
      log =
        capture_log(fn ->
          assert {:error, _} = DeltaEx.load_table("/nonexistent/delta-ex-telemetry-2")
        end)

      assert log =~ "DeltaEx.load_table failed"
    end
  end
end
