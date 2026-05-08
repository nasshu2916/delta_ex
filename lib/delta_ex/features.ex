defmodule DeltaEx.Features do
  @moduledoc false
  alias DeltaEx.Native

  @spec add_feature(DeltaEx.t(), String.t() | atom()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def add_feature(table, feature_name) do
    case Native.add_feature_nif(table, to_string(feature_name)) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end
end
