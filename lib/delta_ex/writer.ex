defmodule DeltaEx.Writer do
  @moduledoc false
  alias DeltaEx.{Config, Native, Telemetry, Util}

  @spec insert(DeltaEx.uri(), DeltaEx.data(), keyword()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def insert(uri, data, opts \\ []) when is_binary(uri) and is_list(data) do
    normalized = Util.stringify_keys(data)
    built = build_opts(opts)

    Telemetry.span(:insert, %{uri: uri, row_count: length(normalized)}, fn ->
      if all_defaults?(built) do
        uri
        |> Native.insert_nif(normalized)
        |> normalize_unit_result()
      else
        uri
        |> Native.insert_with_opts_nif(normalized, built)
        |> normalize_unit_result()
      end
    end)
  end

  defp build_opts(opts) do
    {app_id, app_version} =
      case Keyword.get(opts, :app_transaction) do
        {id, v} when is_binary(id) and is_integer(v) -> {id, v}
        nil -> {nil, nil}
      end

    writer_cfg = Config.writer()

    %{
      app_metadata: normalize_metadata(Keyword.get(opts, :app_metadata)),
      target_file_size:
        Keyword.get(opts, :target_file_size, Keyword.get(writer_cfg, :target_file_size)),
      write_batch_size:
        Keyword.get(opts, :write_batch_size, Keyword.get(writer_cfg, :write_batch_size)),
      app_transaction_app_id: app_id,
      app_transaction_version: app_version,
      storage_options: Util.fetch_storage_options(opts)
    }
  end

  defp all_defaults?(%{
         app_metadata: nil,
         target_file_size: nil,
         write_batch_size: nil,
         app_transaction_app_id: nil,
         app_transaction_version: nil,
         storage_options: nil
       }),
       do: true

  defp all_defaults?(_), do: false

  defp normalize_metadata(nil), do: nil

  defp normalize_metadata(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp normalize_unit_result({}), do: :ok
  defp normalize_unit_result(result), do: result
end
