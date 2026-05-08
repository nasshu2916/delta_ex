defmodule DeltaEx.Maintenance do
  @moduledoc false
  alias DeltaEx.Native

  @spec create_checkpoint(DeltaEx.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def create_checkpoint(table) do
    case Native.create_checkpoint_nif(table) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec cleanup_metadata(DeltaEx.t()) ::
          {:ok, non_neg_integer()} | {:error, DeltaEx.error_reason()}
  def cleanup_metadata(table) do
    case Native.cleanup_metadata_nif(table) do
      {:error, _reason} = error -> error
      n when is_integer(n) -> {:ok, n}
    end
  end

  @spec update_incremental(DeltaEx.t(), keyword()) ::
          {:ok, DeltaEx.version()} | {:error, DeltaEx.error_reason()}
  def update_incremental(table, opts \\ []) do
    max_version = Keyword.get(opts, :max_version)

    case Native.update_incremental_nif(table, max_version) do
      {:error, _} = error -> error
      v when is_integer(v) -> {:ok, v}
    end
  end

  @spec compact_logs(DeltaEx.t(), keyword()) :: :ok | {:error, DeltaEx.error_reason()}
  def compact_logs(table, opts \\ []) do
    start_version = Keyword.get(opts, :start_version, 0)
    end_version = Keyword.fetch!(opts, :end_version)

    case Native.compact_logs_nif(table, start_version, end_version) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec generate_manifest(DeltaEx.t()) :: :ok | {:error, DeltaEx.error_reason()}
  def generate_manifest(table) do
    case Native.generate_manifest_nif(table) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end
end
