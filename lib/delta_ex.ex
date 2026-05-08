defmodule DeltaEx do
  @moduledoc """
  DeltaEx is a NIF-based Elixir wrapper for Delta Lake.

  It provides high-performance access to Delta tables by wrapping the
  [delta-rs](https://github.com/delta-io/delta-rs) library.

  ## Key conversion (`:keys` option)

  Reader-style functions that return rows as maps (`to_list/2`, `load_cdf/2`,
  `query/3`) accept a `:keys` option that controls how column-name keys are
  represented in the returned maps. The native layer always emits string keys;
  this option is applied as a post-processing step in Elixir.

  Accepted values for `:keys`:

    * `:strings` (default) — keys are returned verbatim as `t:String.t/0`.
    * `:atoms` — string keys are converted to atoms via `String.to_atom/1`.
      Use only when the set of column names is bounded and trusted, since
      atoms are not garbage collected.
    * `:atoms!` — string keys are converted via `String.to_existing_atom/1`,
      raising `ArgumentError` for column names whose atom does not yet exist.
      Safe against atom-table exhaustion.

  Behavior details:

    * Conversion is applied to **top-level keys only**. Values are passed
      through unchanged, including nested maps (Delta `struct` columns), so
      a struct-typed column will keep string keys inside even when
      `keys: :atoms` is set at the top level.
    * Keys that are already atoms (e.g. when a future version emits atom
      keys natively) are preserved as-is and are **not** re-validated under
      `:atoms!`.
    * An unrecognised value raises `ArgumentError` before the NIF call.
    * The option has no effect on writer functions (`insert/3`, `merge/4`,
      `update/4`, etc.), which always accept maps with either string or atom
      keys and normalise them to strings internally.

  ## Configuration

  Application-level defaults for commonly tuned options can be supplied via
  `Application` config. Per-call options always take precedence.

      # config/runtime.exs
      config :delta_ex,
        keys: :atoms,
        storage_options: %{"AWS_REGION" => "ap-northeast-1"},
        writer: [target_file_size: 134_217_728, write_batch_size: 8192],
        vacuum: [retention_hours: 168, dry_run: true],
        query: [table_name: "t"]

  See `DeltaEx.Config` for the full list of recognised keys and their
  precedence rules.
  """

  @type t :: reference()
  @type uri :: String.t()
  @type version :: non_neg_integer()
  @type data_row :: map()
  @type data :: [data_row()]
  @type error_reason :: String.t()

  @typedoc """
  Mode for the `:keys` option of reader-style functions.

  See the "Key conversion" section in the module documentation for a
  description of each value.
  """
  @type keys_mode :: :strings | :atoms | :atoms!

  @typedoc """
  Option for `to_list/2`.
  """
  @type to_list_option :: {:keys, keys_mode()}

  @typedoc """
  Option for `query/3`.
  """
  @type query_option :: {:table_name, String.t()} | {:keys, keys_mode()}

  @typedoc """
  Option for `load_cdf/2`.
  """
  @type load_cdf_option ::
          {:starting_version, version()}
          | {:ending_version, version()}
          | {:starting_timestamp, String.t()}
          | {:ending_timestamp, String.t()}
          | {:allow_out_of_range, boolean()}
          | {:keys, keys_mode()}

  alias DeltaEx.{
    Arrow,
    Cdf,
    DeletionVectors,
    Features,
    Maintenance,
    Merge,
    Metadata,
    Operations,
    Query,
    Reader,
    Transactions,
    Writer
  }

  @doc """
  Loads a Delta table from the given URI.

  ## Options

    * `:version` - Load a specific version of the table.

  ## Examples

      {:ok, table} = DeltaEx.load_table("path/to/delta_table")
      {:ok, old_table} = DeltaEx.load_table("path/to/delta_table", version: 5)

  """
  @spec load_table(uri(), keyword()) :: {:ok, t()} | {:error, error_reason()}
  defdelegate load_table(uri, opts \\ []), to: Reader

  @doc """
  Inserts data into the Delta table.
  If the table does not exist, it will be created.

  ## Options

    * `:app_metadata` - A map of string keys/values to attach to the commit.
    * `:target_file_size` - Target size of written parquet files in bytes.
    * `:write_batch_size` - Number of rows per Arrow record batch when writing.
    * `:app_transaction` - `{app_id, version}` tuple to record an idempotent
      application transaction alongside the commit.

  ## Examples

      data = [%{"id" => 1, "name" => "Alice"}, %{"id" => 2, "name" => "Bob"}]
      :ok = DeltaEx.insert("path/to/delta_table", data)
      :ok = DeltaEx.insert("path/to/delta_table", data, app_metadata: %{"job" => "etl"})

  """
  @spec insert(uri(), data(), keyword()) :: :ok | {:error, error_reason()}
  defdelegate insert(uri, data, opts \\ []), to: Writer

  @doc """
  Merges data into the Delta table (Upsert).

  ## Examples

      data = [%{"id" => 1, "name" => "Alice Updated"}]
      :ok = DeltaEx.merge(uri, data, "target.id = source.id")

  """
  @spec merge(uri(), data(), String.t(), keyword()) :: :ok | {:error, error_reason()}
  defdelegate merge(uri, data, predicate, opts \\ []), to: Merge

  @doc """
  Deletes data from the Delta table based on a predicate.

  ## Examples

      :ok = DeltaEx.delete(uri, "id = 1")

  """
  @spec delete(uri(), String.t(), keyword()) :: :ok | {:error, error_reason()}
  defdelegate delete(uri, predicate, opts \\ []), to: Operations

  @doc """
  Updates data in the Delta table based on a predicate.

  The `updates` parameter is a map where keys are column names and values are
  SQL expressions.

  ## Examples

      :ok = DeltaEx.update(uri, %{"age" => "age + 1"}, "id = 1")
      :ok = DeltaEx.update(uri, %{"status" => "'active'"}, "age > 30")

  """
  @spec update(uri(), %{String.t() => String.t()}, String.t(), keyword()) ::
          :ok | {:error, error_reason()}
  defdelegate update(uri, updates, predicate \\ "", opts \\ []), to: Operations

  @doc """
  Returns the current version of the Delta table.
  """
  @spec version(t()) :: version()
  defdelegate version(table), to: Reader

  @doc """
  Returns a list of data files in the Delta table.
  """
  @spec files(t()) :: [uri()]
  defdelegate files(table), to: Reader

  @doc """
  Reads the table data and returns it as a list of maps.

  ## Options

    * `:keys` - Controls how column-name keys are returned. One of `:strings`
      (default), `:atoms`, or `:atoms!`. See the "Key conversion" section in
      the `DeltaEx` module documentation for the full specification, including
      the bounded-atom safety guidance and the top-level-only conversion rule
      for nested struct columns.

  ## Examples

      data = DeltaEx.to_list(table)
      data = DeltaEx.to_list(table, keys: :atoms)

  """
  @spec to_list(t(), [to_list_option()]) :: data()
  defdelegate to_list(table, opts \\ []), to: Reader

  @doc """
  Runs the VACUUM command on the Delta table to delete old data files.

  ## Options

    * `:retention_hours` - Retention period in hours (default: 168, i.e., 7 days).
    * `:dry_run` - If true, only returns the files to be deleted without deleting them (default: true).

  """
  @spec vacuum(t(), keyword()) :: {:ok, [uri()]} | {:error, error_reason()}
  defdelegate vacuum(table, opts \\ []), to: Operations

  @doc """
  Runs the OPTIMIZE command on the Delta table.

  By default, it compacts small files. If `:z_order` option is provided, it
  also performs Z-order clustering on the specified columns.

  ## Options

    * `:z_order` - A list of column names to Z-order by.

  ## Examples

      :ok = DeltaEx.optimize(table)
      :ok = DeltaEx.optimize(table, z_order: ["id", "timestamp"])

  """
  @spec optimize(t(), keyword()) :: :ok | {:error, error_reason()}
  defdelegate optimize(table, opts \\ []), to: Operations

  @doc """
  Runs the FSCK (FileSystem Check) command on the Delta table.

  It identifies "active" files that no longer exist in the underlying storage
  and removes references to them from the transaction log.

  ## Examples

      :ok = DeltaEx.filesystem_check(table)

  """
  @spec filesystem_check(t()) :: :ok | {:error, error_reason()}
  defdelegate filesystem_check(table), to: Operations

  @doc """
  Adds a new column to the Delta table.

  ## Options

    * `:nullable` - Whether the column is nullable (default: true).

  ## Examples

      :ok = DeltaEx.add_column(table, "new_column", :string)
      :ok = DeltaEx.add_column(table, "age", "integer", nullable: false)

  """
  @spec add_column(t(), String.t(), String.t() | atom(), keyword()) ::
          :ok | {:error, error_reason()}
  defdelegate add_column(table, column_name, data_type, opts \\ []), to: Operations

  @doc """
  Restores the Delta table to a previous state.

  ## Options

    * `:version` - The version number to restore to.
    * `:datetime` - The timestamp to restore to (ISO 8601 string).

  ## Examples

      :ok = DeltaEx.restore(table, version: 1)
      :ok = DeltaEx.restore(table, datetime: "2023-01-01T00:00:00Z")

  """
  @spec restore(t(), keyword()) :: :ok | {:error, error_reason()}
  defdelegate restore(table, opts \\ []), to: Operations

  @doc """
  Converts a Parquet table at the given URI to a Delta table.

  ## Examples

      {:ok, table} = DeltaEx.convert_to_delta("path/to/parquet_table")

  """
  @spec convert_to_delta(uri(), keyword()) :: {:ok, t()} | {:error, error_reason()}
  defdelegate convert_to_delta(uri, opts \\ []), to: Operations

  @doc """
  Adds a check constraint to the Delta table.

  ## Examples

      :ok = DeltaEx.add_constraint(table, "valid_age", "age >= 0")

  """
  @spec add_constraint(t(), String.t(), String.t()) :: :ok | {:error, error_reason()}
  defdelegate add_constraint(table, name, expression), to: Operations

  @doc """
  Drops a check constraint from the Delta table.

  ## Examples

      :ok = DeltaEx.drop_constraint(table, "valid_age")

  """
  @spec drop_constraint(DeltaEx.t(), String.t()) :: :ok | {:error, error_reason()}
  defdelegate drop_constraint(table, name), to: Operations

  @doc """
  Enables a specific feature in the Delta table's protocol.

  Supported features include:
  * `"deletionVectors"`
  * `"changeDataFeed"`
  * `"v2Checkpoint"`

  ## Examples

      :ok = DeltaEx.add_feature(table, "deletionVectors")

  """
  @spec add_feature(t(), String.t() | atom()) :: :ok | {:error, error_reason()}
  defdelegate add_feature(table, feature_name), to: Features

  @doc """
  Returns the commit history of the Delta table.

  ## Options

    * `:limit` - Maximum number of commits to return (most recent first).

  ## Examples

      {:ok, commits} = DeltaEx.history(table)
      {:ok, recent} = DeltaEx.history(table, limit: 10)

  """
  @spec history(t(), keyword()) :: {:ok, [map()]} | {:error, error_reason()}
  defdelegate history(table, opts \\ []), to: Metadata

  @doc """
  Returns the reader/writer protocol versions and supported features.

  ## Examples

      {:ok, %{min_reader_version: 1, min_writer_version: 2}} = DeltaEx.protocol(table)

  """
  @spec protocol(t()) :: {:ok, map()} | {:error, error_reason()}
  defdelegate protocol(table), to: Metadata

  @doc """
  Returns the names of partition columns.
  """
  @spec partition_columns(t()) :: {:ok, [String.t()]} | {:error, error_reason()}
  defdelegate partition_columns(table), to: Metadata

  @doc """
  Returns absolute URIs of all active data files in the current table version.
  """
  @spec file_uris(t()) :: [uri()]
  defdelegate file_uris(table), to: Metadata

  @doc """
  Returns an approximate row count computed from per-file statistics.

  Files missing the `numRecords` statistic are skipped, so the count may be
  lower than the true row count.
  """
  @spec count(t()) :: {:ok, non_neg_integer()} | {:error, error_reason()}
  defdelegate count(table), to: Metadata

  @doc """
  Returns `true` if the URI points to a valid Delta table.

  ## Examples

      true = DeltaEx.delta_table?("path/to/delta_table")
      false = DeltaEx.delta_table?("path/to/non_delta")

  """
  @spec delta_table?(uri(), keyword()) :: boolean()
  defdelegate delta_table?(uri, opts \\ []), to: Metadata

  @doc """
  Sets the human-readable table name in the table metadata.
  """
  @spec set_table_name(t(), String.t()) :: :ok | {:error, error_reason()}
  defdelegate set_table_name(table, name), to: Metadata

  @doc """
  Sets the table description in the table metadata.
  """
  @spec set_table_description(t(), String.t()) :: :ok | {:error, error_reason()}
  defdelegate set_table_description(table, description), to: Metadata

  @doc """
  Sets table-level properties.

  ## Options

    * `:raise_if_not_exists` - Raise if a property does not yet exist (default: true).

  ## Examples

      :ok = DeltaEx.set_table_properties(table, %{
        "delta.minReaderVersion" => "3",
        "delta.minWriterVersion" => "7"
      })

  """
  @spec set_table_properties(t(), %{String.t() => String.t()}, keyword()) ::
          :ok | {:error, error_reason()}
  defdelegate set_table_properties(table, properties, opts \\ []), to: Metadata

  @doc """
  Creates a checkpoint at the current table version.

  Checkpoints make later table loads faster by collapsing prior log entries.
  """
  @spec create_checkpoint(t()) :: :ok | {:error, error_reason()}
  defdelegate create_checkpoint(table), to: Maintenance

  @doc """
  Removes expired log files based on the table's `logRetentionDuration`
  property (default 30 days). Returns the number of deleted log files.
  """
  @spec cleanup_metadata(t()) :: {:ok, non_neg_integer()} | {:error, error_reason()}
  defdelegate cleanup_metadata(table), to: Maintenance

  @doc """
  Generates the `_symlink_format_manifest` for use with external engines such
  as Presto, Athena, or BigQuery.
  """
  @spec generate_manifest(t()) :: :ok | {:error, error_reason()}
  defdelegate generate_manifest(table), to: Maintenance

  @doc """
  Reads the Change Data Feed of a Delta table.

  Either `:starting_version` or `:starting_timestamp` must be provided. The
  returned rows include the original columns plus CDF metadata columns such as
  `_change_type`, `_commit_version`, and `_commit_timestamp`.

  ## Options

    * `:starting_version` - First version (inclusive) to read.
    * `:ending_version` - Last version (inclusive) to read.
    * `:starting_timestamp` - ISO 8601 timestamp string to start from.
    * `:ending_timestamp` - ISO 8601 timestamp string to end at.
    * `:allow_out_of_range` - Return an empty list instead of erroring when the
      range is out of bounds (default: false).
    * `:keys` - `:strings` (default), `:atoms`, or `:atoms!`. See the
      "Key conversion" section in the `DeltaEx` module documentation.

  ## Examples

      {:ok, rows} = DeltaEx.load_cdf(table, starting_version: 0)
      {:ok, rows} = DeltaEx.load_cdf(table, starting_version: 0, keys: :atoms)

  """
  @spec load_cdf(t(), [load_cdf_option()]) :: {:ok, data()} | {:error, error_reason()}
  defdelegate load_cdf(table, opts \\ []), to: Cdf

  @doc """
  Returns the deletion vector descriptors of all data files that have one.

  Each entry is a map with `:path`, `:storage_type`, `:path_or_inline_dv`,
  `:offset`, `:size_in_bytes`, and `:cardinality`.
  """
  @spec deletion_vectors(t()) :: {:ok, [map()]} | {:error, error_reason()}
  defdelegate deletion_vectors(table), to: DeletionVectors

  @doc """
  Runs an arbitrary DataFusion SQL query against the Delta table.

  The table is registered under the name given in `:table_name` (default `"t"`)
  for the duration of the query.

  ## Options

    * `:table_name` - The name to register the table under (default: `"t"`).
    * `:keys` - `:strings` (default), `:atoms`, or `:atoms!`. See the
      "Key conversion" section in the `DeltaEx` module documentation.

  ## Examples

      {:ok, rows} = DeltaEx.query(table, "SELECT id, name FROM t WHERE id > 10")
      {:ok, rows} = DeltaEx.query(table, "SELECT * FROM users", table_name: "users")
      {:ok, rows} = DeltaEx.query(table, "SELECT id FROM t", keys: :atoms)

  """
  @spec query(t(), String.t(), [query_option()]) ::
          {:ok, data()} | {:error, error_reason()}
  defdelegate query(table, sql, opts \\ []), to: Query

  @doc """
  Updates metadata on a column in the Delta table schema.

  Existing metadata keys are updated; new keys are inserted. Metadata keys
  starting with `delta.` are protected and cannot be modified.

  ## Examples

      :ok = DeltaEx.set_column_metadata(table, "id", %{"description" => "primary key"})

  """
  @spec set_column_metadata(t(), String.t(), %{String.t() => String.t()}) ::
          :ok | {:error, error_reason()}
  defdelegate set_column_metadata(table, field_name, metadata), to: Metadata

  @doc """
  Incrementally updates the in-memory table state to the latest (or specified)
  version, applying only newly added log entries.

  This is forward-only — to load an older version, use `load_table/2` instead.

  ## Options

    * `:max_version` - Stop applying log entries after this version.

  ## Examples

      {:ok, version} = DeltaEx.update_incremental(table)
      {:ok, version} = DeltaEx.update_incremental(table, max_version: 7)

  """
  @spec update_incremental(t(), keyword()) ::
          {:ok, version()} | {:error, error_reason()}
  defdelegate update_incremental(table, opts \\ []), to: Maintenance

  @doc """
  Compacts a contiguous range of JSON commit log files into a single
  `_log_compaction` file, reducing the number of small log entries that must be
  read at table load time.

  ## Options

    * `:start_version` - First commit version to compact (default: `0`).
    * `:end_version` - Last commit version (inclusive) to compact. Required.

  ## Examples

      :ok = DeltaEx.compact_logs(table, end_version: 9)
      :ok = DeltaEx.compact_logs(table, start_version: 10, end_version: 19)

  """
  @spec compact_logs(t(), keyword()) :: :ok | {:error, error_reason()}
  defdelegate compact_logs(table, opts \\ []), to: Maintenance

  @doc """
  Returns the current data of the Delta table encoded as Arrow IPC stream
  bytes.

  Pair this with libraries such as Explorer to load the result into a
  `DataFrame`:

      {:ok, ipc} = DeltaEx.to_arrow_ipc(table)
      df = Explorer.DataFrame.load_ipc_stream!(ipc)

  """
  @spec to_arrow_ipc(t()) :: {:ok, binary()} | {:error, error_reason()}
  defdelegate to_arrow_ipc(table), to: Arrow

  @doc """
  Records an application transaction (`txn` action) on the table without
  writing data. Subsequent calls to `app_transaction_version/2` for the same
  `app_id` will return the latest committed `version`.

  This is the idempotency primitive used by streaming systems such as
  Structured Streaming.
  """
  @spec commit_app_transaction(t(), String.t(), integer()) ::
          :ok | {:error, error_reason()}
  defdelegate commit_app_transaction(table, app_id, version), to: Transactions

  @doc """
  Returns the latest application transaction version recorded under the given
  `app_id`, or `nil` if the application has not committed yet.
  """
  @spec app_transaction_version(t(), String.t()) ::
          {:ok, integer() | nil} | {:error, error_reason()}
  defdelegate app_transaction_version(table, app_id), to: Transactions
end
