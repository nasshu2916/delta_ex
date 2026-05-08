defmodule DeltaEx.Reader do
  @moduledoc false
  alias DeltaEx.{Native, Telemetry, Util}

  @spec load_table(DeltaEx.uri(), keyword()) ::
          {:ok, DeltaEx.t()} | {:error, DeltaEx.error_reason()}
  def load_table(uri, opts \\ []) do
    version = Keyword.get(opts, :version)
    storage_options = Util.fetch_storage_options(opts)

    Telemetry.span(:load_table, %{uri: uri, version: version}, fn ->
      case Native.load_table_nif(uri, version, storage_options) do
        {:error, _reason} = error -> error
        table -> {:ok, table}
      end
    end)
  end

  @spec version(DeltaEx.t()) :: DeltaEx.version()
  def version(table), do: Native.version(table)

  @spec files(DeltaEx.t()) :: [DeltaEx.uri()]
  def files(table), do: Native.files(table)

  @spec to_list(DeltaEx.t(), [DeltaEx.to_list_option()]) :: DeltaEx.data()
  def to_list(table, opts \\ []) do
    table
    |> Native.to_list()
    |> Util.convert_keys(Util.fetch_keys_option(opts))
  end
end
