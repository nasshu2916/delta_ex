defmodule DeltaEx.Cdf do
  @moduledoc false
  alias DeltaEx.{Native, Telemetry, Util}

  @spec load_cdf(DeltaEx.t(), [DeltaEx.load_cdf_option()]) ::
          {:ok, DeltaEx.data()} | {:error, DeltaEx.error_reason()}
  def load_cdf(table, opts \\ []) do
    starting_version = Keyword.get(opts, :starting_version)
    ending_version = Keyword.get(opts, :ending_version)
    starting_timestamp = Keyword.get(opts, :starting_timestamp)
    ending_timestamp = Keyword.get(opts, :ending_timestamp)
    allow_out_of_range = Keyword.get(opts, :allow_out_of_range, false)
    keys = Util.fetch_keys_option(opts)

    metadata = %{
      starting_version: starting_version,
      ending_version: ending_version,
      starting_timestamp: starting_timestamp,
      ending_timestamp: ending_timestamp
    }

    Telemetry.span(:load_cdf, metadata, fn ->
      case Native.load_cdf_nif(
             table,
             starting_version,
             ending_version,
             starting_timestamp,
             ending_timestamp,
             allow_out_of_range
           ) do
        {:error, _} = error -> error
        list when is_list(list) -> {:ok, Util.convert_keys(list, keys)}
      end
    end)
  end
end
