defmodule DeltaEx.Metadata do
  @moduledoc false
  alias DeltaEx.{Native, Util}

  @spec history(DeltaEx.t(), keyword()) :: {:ok, [map()]} | {:error, DeltaEx.error_reason()}
  def history(table, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    case Native.history_nif(table, limit) do
      {:error, _reason} = error -> error
      list when is_list(list) -> {:ok, list}
    end
  end

  @spec protocol(DeltaEx.t()) :: {:ok, map()} | {:error, DeltaEx.error_reason()}
  def protocol(table) do
    case Native.protocol_nif(table) do
      {:error, _reason} = error -> error
      map when is_map(map) -> {:ok, map}
    end
  end

  @spec partition_columns(DeltaEx.t()) :: {:ok, [String.t()]} | {:error, DeltaEx.error_reason()}
  def partition_columns(table) do
    case Native.partition_columns_nif(table) do
      {:error, _reason} = error -> error
      list when is_list(list) -> {:ok, list}
    end
  end

  @spec file_uris(DeltaEx.t()) :: [DeltaEx.uri()]
  def file_uris(table), do: Native.file_uris_nif(table)

  @spec count(DeltaEx.t()) :: {:ok, non_neg_integer()} | {:error, DeltaEx.error_reason()}
  def count(table) do
    case Native.count_nif(table) do
      {:error, _reason} = error -> error
      n when is_integer(n) -> {:ok, n}
    end
  end

  @spec delta_table?(DeltaEx.uri(), keyword()) :: boolean()
  def delta_table?(uri, opts \\ []) when is_binary(uri) do
    Native.is_delta_table_nif(uri, DeltaEx.Util.fetch_storage_options(opts))
  end

  @spec set_table_name(DeltaEx.t(), String.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def set_table_name(table, name) when is_binary(name) do
    case Native.set_table_name_nif(table, name) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec set_table_description(DeltaEx.t(), String.t()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def set_table_description(table, description) when is_binary(description) do
    case Native.set_table_description_nif(table, description) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec set_column_metadata(DeltaEx.t(), String.t(), %{String.t() => String.t()}) ::
          :ok | {:error, DeltaEx.error_reason()}
  def set_column_metadata(table, field_name, metadata)
      when is_binary(field_name) and is_map(metadata) do
    case Native.set_column_metadata_nif(table, field_name, Util.stringify_keys(metadata)) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec set_table_properties(DeltaEx.t(), %{String.t() => String.t()}, keyword()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def set_table_properties(table, properties, opts \\ []) when is_map(properties) do
    raise_if_not_exists = Keyword.get(opts, :raise_if_not_exists, true)

    case Native.set_table_properties_nif(
           table,
           Util.stringify_keys(properties),
           raise_if_not_exists
         ) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end
end
