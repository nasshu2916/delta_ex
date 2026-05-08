defmodule DeltaEx.Operations do
  @moduledoc false
  alias DeltaEx.{Config, Native, Telemetry, Util}

  @spec delete(DeltaEx.uri(), String.t(), keyword()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def delete(uri, predicate, opts \\ []) when is_binary(uri) and is_binary(predicate) do
    Telemetry.span(:delete, %{uri: uri, predicate: predicate}, fn ->
      uri
      |> Native.delete_nif(predicate, Util.fetch_storage_options(opts))
      |> normalize_unit_result()
    end)
  end

  @spec update(DeltaEx.uri(), %{String.t() => String.t()}, String.t(), keyword()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def update(uri, updates, predicate \\ "", opts \\ [])
      when is_binary(uri) and is_map(updates) and is_binary(predicate) do
    Telemetry.span(:update, %{uri: uri, predicate: predicate}, fn ->
      uri
      |> Native.update_nif(
        Util.stringify_keys(updates),
        predicate,
        Util.fetch_storage_options(opts)
      )
      |> normalize_unit_result()
    end)
  end

  @spec vacuum(DeltaEx.t(), keyword()) ::
          {:ok, [DeltaEx.uri()]} | {:error, DeltaEx.error_reason()}
  def vacuum(table, opts \\ []) do
    cfg = Config.vacuum()
    retention_hours = Keyword.get(opts, :retention_hours, Keyword.get(cfg, :retention_hours))
    dry_run = Keyword.get(opts, :dry_run, Keyword.get(cfg, :dry_run, true))

    Telemetry.span(:vacuum, %{dry_run: dry_run}, fn ->
      Native.vacuum_nif(table, retention_hours, dry_run)
    end)
  end

  @spec optimize(DeltaEx.t(), keyword()) :: :ok | {:error, DeltaEx.error_reason()}
  def optimize(table, opts \\ []) do
    z_order_columns = Keyword.get(opts, :z_order)

    Telemetry.span(:optimize, %{z_order: z_order_columns}, fn ->
      table
      |> Native.optimize_nif(z_order_columns)
      |> normalize_unit_result()
    end)
  end

  @spec filesystem_check(DeltaEx.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def filesystem_check(table) do
    table
    |> Native.filesystem_check_nif()
    |> normalize_unit_result()
  end

  @spec restore(DeltaEx.t(), keyword()) :: :ok | {:error, DeltaEx.error_reason()}
  def restore(table, opts \\ []) do
    version = Keyword.get(opts, :version)
    datetime = Keyword.get(opts, :datetime)

    case Native.restore_nif(table, version, datetime) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec convert_to_delta(DeltaEx.uri(), keyword()) ::
          {:ok, DeltaEx.t()} | {:error, DeltaEx.error_reason()}
  def convert_to_delta(uri, opts \\ []) do
    case Native.convert_to_delta_nif(uri, Util.fetch_storage_options(opts)) do
      {:error, _reason} = error -> error
      table -> {:ok, table}
    end
  end

  @spec add_column(DeltaEx.t(), String.t(), String.t() | atom(), keyword()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def add_column(table, column_name, data_type, opts \\ []) do
    nullable = Keyword.get(opts, :nullable, true)

    case Native.add_column_nif(table, column_name, to_string(data_type), nullable) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec add_constraint(DeltaEx.t(), String.t(), String.t()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def add_constraint(table, name, expression) do
    case Native.add_constraint_nif(table, name, expression) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec drop_constraint(DeltaEx.t(), String.t()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def drop_constraint(table, name) do
    case Native.drop_constraint_nif(table, name) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp normalize_unit_result({}), do: :ok
  defp normalize_unit_result(result), do: result
end
