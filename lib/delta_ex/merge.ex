defmodule DeltaEx.Merge do
  @moduledoc false
  alias DeltaEx.{Native, Telemetry, Util}

  @spec merge(DeltaEx.uri(), DeltaEx.data(), String.t(), keyword()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def merge(uri, data, predicate, opts \\ [])
      when is_binary(uri) and is_list(data) and is_binary(predicate) do
    normalized = Util.stringify_keys(data)
    metadata = %{uri: uri, predicate: predicate, row_count: length(normalized)}

    Telemetry.span(:merge, metadata, fn ->
      uri
      |> Native.merge_nif(normalized, predicate, Util.fetch_storage_options(opts))
      |> normalize_unit_result()
    end)
  end

  defp normalize_unit_result({}), do: :ok
  defp normalize_unit_result(result), do: result
end
