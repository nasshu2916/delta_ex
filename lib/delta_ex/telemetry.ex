defmodule DeltaEx.Telemetry do
  @moduledoc """
  `:telemetry` integration for DeltaEx.

  Public read / write entry points are wrapped with `:telemetry.span/3` so
  applications can observe Delta operations using the standard telemetry
  pipeline (Phoenix-style metrics, Logger, OpenTelemetry exporters, etc.).
  For projects that only need timing and error logs,
  `attach_default_logger/1` is a one-line setup.

  ## Events

  All instrumented operations emit the three standard span events:

      [:delta_ex, <operation>, :start]
      [:delta_ex, <operation>, :stop]
      [:delta_ex, <operation>, :exception]

  `:start` fires before the NIF call. `:stop` fires once the call returns,
  whether it succeeded or returned `{:error, _}`. `:exception` only fires
  when the function itself raises (NIF panic, validation `ArgumentError`,
  etc.) — a returned `{:error, _}` is **not** an exception.

  Instrumented operations:

  | Event prefix                   | Emitted by                       |
  | ------------------------------ | -------------------------------- |
  | `[:delta_ex, :insert]`         | `DeltaEx.insert/3`               |
  | `[:delta_ex, :merge]`          | `DeltaEx.merge/4`                |
  | `[:delta_ex, :delete]`         | `DeltaEx.delete/3`               |
  | `[:delta_ex, :update]`         | `DeltaEx.update/4`               |
  | `[:delta_ex, :vacuum]`         | `DeltaEx.vacuum/2`               |
  | `[:delta_ex, :optimize]`       | `DeltaEx.optimize/2`             |
  | `[:delta_ex, :load_table]`     | `DeltaEx.load_table/2`           |
  | `[:delta_ex, :load_cdf]`       | `DeltaEx.load_cdf/2`             |
  | `[:delta_ex, :query]`          | `DeltaEx.query/3`                |

  Synchronous accessors that operate on already-loaded table state
  (`version/1`, `files/1`, `to_list/2`, `count/1`, etc.) are intentionally
  not instrumented — they perform no I/O.

  ## Measurements

  Inherited from `:telemetry.span/3`:

    * `:system_time` *(start only)* — `System.system_time/0` at the call
      site. Useful for correlating with wall-clock logs.
    * `:monotonic_time` *(start and stop)* — `System.monotonic_time/0`.
    * `:duration` *(stop and exception)* — elapsed time in `:native` units.

  Convert duration with `System.convert_time_unit(duration, :native, unit)`.

  ## Metadata

  Common keys (present on every event):

    * `:operation` — operation atom (e.g. `:insert`). Matches the event's
      second segment, but is also handy when one handler subscribes to many
      events and dispatches on `metadata.operation`.

  URI-based ops (`:insert`, `:merge`, `:delete`, `:update`, `:load_table`)
  additionally include:

    * `:uri` — the table URI passed by the caller. May contain credentials
      if the caller embedded them in the URI itself; see "PII / sensitive
      data" below.

  Per-operation extras:

  | Operation     | Extra metadata keys                                    |
  | ------------- | ------------------------------------------------------ |
  | `:insert`     | `:row_count`                                           |
  | `:merge`      | `:row_count`, `:predicate`                             |
  | `:delete`     | `:predicate`                                           |
  | `:update`     | `:predicate`                                           |
  | `:load_table` | `:version` (may be `nil` for HEAD)                     |
  | `:load_cdf`   | `:starting_version`, `:ending_version`,                |
  |               | `:starting_timestamp`, `:ending_timestamp`             |
  | `:query`      | `:table_name`, `:sql`                                  |
  | `:vacuum`     | `:dry_run`                                             |
  | `:optimize`   | `:z_order` (`nil` for plain compaction)                |

  Stop-event metadata adds:

    * `:result` — `:ok` on success, `:error` on a returned `{:error, _}`.
    * `:error` — present only when `result: :error`. The error reason
      string returned by the NIF.

  Exception-event metadata follows the standard `:telemetry.span/3` shape:

    * `:kind` — `:throw`, `:error`, or `:exit`.
    * `:reason` — the raised value or exception struct.
    * `:stacktrace`.

  ## PII / sensitive data

  `:uri`, `:predicate`, and `:sql` are passed through verbatim — they may
  contain sensitive values (signed URLs, IDs, embedded credentials,
  literal user data). Treat them as you would request URLs in HTTP access
  logs: redact before shipping to external systems if your data
  classification requires it. The default Logger handler emits `:uri` and
  `:row_count` only.

  ## Default Logger handler

  For a quick start, attach the bundled handler at application boot:

      # lib/my_app/application.ex
      def start(_type, _args) do
          DeltaEx.Telemetry.attach_default_logger(:info)
          # ...
      end

  Sample output:

      [info]  DeltaEx.insert ok in 16949us uri="s3://bucket/users" row_count=2
      [info]  DeltaEx.merge ok in 42103us uri="s3://bucket/users" row_count=10
      [error] DeltaEx.load_table failed in 1204us: "Generic S3 error: ..."

  Errors are always logged at `:error`; the success-path level is
  configurable. Detach with `detach_default_logger/0`.

  ## Custom handler

  When the default handler is too coarse (e.g. you want structured logs or
  histograms), attach your own with `:telemetry.attach_many/4`. Use a
  module function capture rather than an anonymous function to avoid
  `:telemetry`'s "local function" performance warning.

      defmodule MyApp.DeltaTracer do
        require Logger

        @events [
          [:delta_ex, :insert, :stop],
          [:delta_ex, :merge, :stop],
          [:delta_ex, :load_table, :stop]
        ]

        def attach do
          :telemetry.attach_many("my-app-delta", @events, &__MODULE__.handle/4, nil)
        end

        def handle([:delta_ex, op, :stop], %{duration: d}, %{result: result} = meta, _) do
          ms = System.convert_time_unit(d, :native, :microsecond) / 1000
          Logger.info(fn ->
            \"\"\"
            delta_op=\#{op} result=\#{result} duration_ms=\#{ms} uri=\#{inspect(meta[:uri])}
            \"\"\"
          end)
        end
      end

  ## Integration with `:telemetry_metrics`

  Aggregate per-operation latency and error rates as Prometheus / StatsD
  metrics:

      # lib/my_app/metrics.ex
      import Telemetry.Metrics

      def metrics do
        [
          summary("delta_ex.insert.stop.duration",
            unit: {:native, :millisecond},
            tags: [:result]
          ),
          summary("delta_ex.load_table.stop.duration",
            unit: {:native, :millisecond},
            tags: [:result]
          ),
          counter("delta_ex.merge.stop.duration",
            tags: [:result]
          )
        ]
      end

  Pair this with `TelemetryMetricsPrometheus` (or any other reporter)
  to expose the metrics on a scrape endpoint.

  ## Testing telemetry in your application

  In ExUnit, attach a handler that forwards events to the test process:

      setup do
        parent = self()
        :telemetry.attach(
          "test-\#{System.unique_integer()}",
          [:delta_ex, :insert, :stop],
          fn _name, m, meta, _ -> send(parent, {:delta_ex_insert, m, meta}) end,
          nil
        )

        on_exit(fn -> :telemetry.detach("test-...") end)
      end

      test "insert is observed" do
        :ok = DeltaEx.insert(uri, [%{"id" => 1}])
        assert_receive {:delta_ex_insert, %{duration: _}, %{result: :ok, row_count: 1}}
      end
  """

  require Logger

  @handler_id "delta_ex-default-logger"

  @operations [
    :insert,
    :merge,
    :delete,
    :update,
    :vacuum,
    :optimize,
    :load_table,
    :load_cdf,
    :query
  ]

  @doc false
  @spec span(atom(), map(), (-> result)) :: result when result: var
  def span(operation, metadata, fun) when is_atom(operation) and is_map(metadata) do
    metadata = Map.put(metadata, :operation, operation)

    :telemetry.span([:delta_ex, operation], metadata, fn ->
      result = fun.()
      {result, Map.merge(metadata, stop_metadata(result))}
    end)
  end

  defp stop_metadata(:ok), do: %{result: :ok}
  defp stop_metadata({:ok, _}), do: %{result: :ok}
  defp stop_metadata({:error, reason}), do: %{result: :error, error: reason}
  defp stop_metadata(_), do: %{result: :ok}

  @doc """
  Attaches a default `Logger` handler that logs every DeltaEx operation.

  Successes are logged at `level` (default `:info`); errors and exceptions
  are always logged at `:error`. Returns `:ok` if the handler was attached,
  or `{:error, :already_exists}` when called more than once.
  """
  @spec attach_default_logger(Logger.level()) :: :ok | {:error, :already_exists}
  def attach_default_logger(level \\ :info) do
    events =
      Enum.flat_map(@operations, fn op ->
        [
          [:delta_ex, op, :stop],
          [:delta_ex, op, :exception]
        ]
      end)

    :telemetry.attach_many(@handler_id, events, &__MODULE__.handle_event/4, %{level: level})
  end

  @doc """
  Detaches the default logger handler installed by `attach_default_logger/1`.
  """
  @spec detach_default_logger() :: :ok | {:error, :not_found}
  def detach_default_logger, do: :telemetry.detach(@handler_id)

  @doc false
  def handle_event([:delta_ex, op, :stop], measurements, metadata, %{level: level}) do
    duration_us =
      System.convert_time_unit(measurements.duration, :native, :microsecond)

    case Map.get(metadata, :result) do
      :error ->
        Logger.error(fn ->
          "DeltaEx.#{op} failed in #{duration_us}us: #{inspect(metadata[:error])}"
        end)

      _ ->
        Logger.log(level, fn ->
          "DeltaEx.#{op} ok in #{duration_us}us#{format_extras(metadata)}"
        end)
    end
  end

  def handle_event([:delta_ex, op, :exception], measurements, metadata, _config) do
    duration_us =
      System.convert_time_unit(measurements.duration, :native, :microsecond)

    Logger.error(fn ->
      "DeltaEx.#{op} raised after #{duration_us}us: #{inspect(metadata[:reason])}"
    end)
  end

  defp format_extras(metadata) do
    metadata
    |> Map.take([:uri, :row_count])
    |> Enum.map_join("", fn {k, v} -> " #{k}=#{inspect(v)}" end)
  end
end
