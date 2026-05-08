defmodule DeltaEx.Query do
  @moduledoc false
  alias DeltaEx.{Config, Native, Telemetry, Util}

  @spec query(DeltaEx.t(), String.t(), [DeltaEx.query_option()]) ::
          {:ok, DeltaEx.data()} | {:error, DeltaEx.error_reason()}
  def query(table, sql, opts \\ []) when is_binary(sql) do
    table_name =
      Keyword.get(opts, :table_name, Keyword.get(Config.query(), :table_name, "t"))

    keys = Util.fetch_keys_option(opts)

    Telemetry.span(:query, %{table_name: table_name, sql: sql}, fn ->
      case Native.query_sql_nif(table, table_name, sql) do
        {:error, _} = error -> error
        list when is_list(list) -> {:ok, Util.convert_keys(list, keys)}
      end
    end)
  end
end
