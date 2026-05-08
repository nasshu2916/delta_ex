defmodule DeltaEx.Native do
  @moduledoc false
  use Rustler, otp_app: :delta_ex, crate: "delta_ex_native"

  @spec load_table_nif(
          DeltaEx.uri(),
          DeltaEx.version() | nil,
          %{String.t() => String.t()} | nil
        ) :: DeltaEx.t() | {:error, DeltaEx.error_reason()}
  def load_table_nif(_uri, _version, _storage_options),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec insert_nif(DeltaEx.uri(), DeltaEx.data()) :: {} | {:error, DeltaEx.error_reason()}
  def insert_nif(_uri, _data), do: :erlang.nif_error(:nif_not_loaded)

  @spec insert_with_opts_nif(DeltaEx.uri(), DeltaEx.data(), map()) ::
          {} | {:error, DeltaEx.error_reason()}
  def insert_with_opts_nif(_uri, _data, _opts), do: :erlang.nif_error(:nif_not_loaded)

  @spec to_arrow_ipc_nif(DeltaEx.t()) :: binary() | {:error, DeltaEx.error_reason()}
  def to_arrow_ipc_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec compact_logs_nif(DeltaEx.t(), integer(), integer()) ::
          {} | {:error, DeltaEx.error_reason()}
  def compact_logs_nif(_table, _start_version, _end_version),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec app_transaction_version_nif(DeltaEx.t(), String.t()) ::
          integer() | nil | {:error, DeltaEx.error_reason()}
  def app_transaction_version_nif(_table, _app_id), do: :erlang.nif_error(:nif_not_loaded)

  @spec commit_app_transaction_nif(DeltaEx.t(), String.t(), integer()) ::
          {} | {:error, DeltaEx.error_reason()}
  def commit_app_transaction_nif(_table, _app_id, _version),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec merge_nif(
          DeltaEx.uri(),
          DeltaEx.data(),
          String.t(),
          %{String.t() => String.t()} | nil
        ) :: {} | {:error, DeltaEx.error_reason()}
  def merge_nif(_uri, _data, _predicate, _storage_options),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec delete_nif(DeltaEx.uri(), String.t(), %{String.t() => String.t()} | nil) ::
          {} | {:error, DeltaEx.error_reason()}
  def delete_nif(_uri, _predicate, _storage_options),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec update_nif(
          DeltaEx.uri(),
          %{String.t() => String.t()},
          String.t(),
          %{String.t() => String.t()} | nil
        ) :: {} | {:error, DeltaEx.error_reason()}
  def update_nif(_uri, _updates, _predicate, _storage_options),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec version(DeltaEx.t()) :: DeltaEx.version()
  def version(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec files(DeltaEx.t()) :: [DeltaEx.uri()]
  def files(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec to_list(DeltaEx.t()) :: DeltaEx.data()
  def to_list(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec vacuum_nif(DeltaEx.t(), integer() | nil, boolean()) ::
          {:ok, [DeltaEx.uri()]} | {:error, DeltaEx.error_reason()}
  def vacuum_nif(_table, _retention_hours, _dry_run), do: :erlang.nif_error(:nif_not_loaded)

  @spec optimize_nif(DeltaEx.t(), [String.t()] | nil) :: {} | {:error, DeltaEx.error_reason()}
  def optimize_nif(_table, _z_order_columns), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_column_nif(DeltaEx.t(), String.t(), String.t(), boolean()) ::
          {} | {:error, DeltaEx.error_reason()}
  def add_column_nif(_table, _column_name, _data_type, _nullable),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec restore_nif(DeltaEx.t(), integer() | nil, String.t() | nil) ::
          :ok | {:error, DeltaEx.error_reason()}
  def restore_nif(_table, _version, _datetime), do: :erlang.nif_error(:nif_not_loaded)

  @spec convert_to_delta_nif(DeltaEx.uri(), %{String.t() => String.t()} | nil) ::
          DeltaEx.t() | {:error, DeltaEx.error_reason()}
  def convert_to_delta_nif(_uri, _storage_options), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_constraint_nif(DeltaEx.t(), String.t(), String.t()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def add_constraint_nif(_table, _name, _expression), do: :erlang.nif_error(:nif_not_loaded)

  @spec drop_constraint_nif(DeltaEx.t(), String.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def drop_constraint_nif(_table, _name), do: :erlang.nif_error(:nif_not_loaded)

  @spec filesystem_check_nif(DeltaEx.t()) :: {} | {:error, DeltaEx.error_reason()}
  def filesystem_check_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_feature_nif(DeltaEx.t(), String.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def add_feature_nif(_table, _feature_name), do: :erlang.nif_error(:nif_not_loaded)

  @spec history_nif(DeltaEx.t(), non_neg_integer() | nil) ::
          [map()] | {:error, DeltaEx.error_reason()}
  def history_nif(_table, _limit), do: :erlang.nif_error(:nif_not_loaded)

  @spec protocol_nif(DeltaEx.t()) :: map() | {:error, DeltaEx.error_reason()}
  def protocol_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec partition_columns_nif(DeltaEx.t()) :: [String.t()] | {:error, DeltaEx.error_reason()}
  def partition_columns_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec file_uris_nif(DeltaEx.t()) :: [String.t()] | {:error, DeltaEx.error_reason()}
  def file_uris_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec count_nif(DeltaEx.t()) :: integer() | {:error, DeltaEx.error_reason()}
  def count_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec is_delta_table_nif(DeltaEx.uri(), %{String.t() => String.t()} | nil) :: boolean()
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_delta_table_nif(_uri, _storage_options), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_table_name_nif(DeltaEx.t(), String.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def set_table_name_nif(_table, _name), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_table_description_nif(DeltaEx.t(), String.t()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def set_table_description_nif(_table, _description), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_table_properties_nif(DeltaEx.t(), %{String.t() => String.t()}, boolean()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def set_table_properties_nif(_table, _properties, _raise_if_not_exists),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec create_checkpoint_nif(DeltaEx.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def create_checkpoint_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec cleanup_metadata_nif(DeltaEx.t()) :: integer() | {:error, DeltaEx.error_reason()}
  def cleanup_metadata_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec generate_manifest_nif(DeltaEx.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def generate_manifest_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec load_cdf_nif(
          DeltaEx.t(),
          integer() | nil,
          integer() | nil,
          String.t() | nil,
          String.t() | nil,
          boolean()
        ) :: DeltaEx.data() | {:error, DeltaEx.error_reason()}
  def load_cdf_nif(
        _table,
        _starting_version,
        _ending_version,
        _starting_timestamp,
        _ending_timestamp,
        _allow_out_of_range
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @spec deletion_vectors_nif(DeltaEx.t()) :: [map()] | {:error, DeltaEx.error_reason()}
  def deletion_vectors_nif(_table), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_sql_nif(DeltaEx.t(), String.t(), String.t()) ::
          DeltaEx.data() | {:error, DeltaEx.error_reason()}
  def query_sql_nif(_table, _table_name, _sql), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_column_metadata_nif(DeltaEx.t(), String.t(), %{String.t() => String.t()}) ::
          :ok | {:error, DeltaEx.error_reason()}
  def set_column_metadata_nif(_table, _field_name, _metadata),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec update_incremental_nif(DeltaEx.t(), integer() | nil) ::
          integer() | {:error, DeltaEx.error_reason()}
  def update_incremental_nif(_table, _max_version), do: :erlang.nif_error(:nif_not_loaded)
end
