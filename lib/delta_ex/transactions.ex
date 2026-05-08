defmodule DeltaEx.Transactions do
  @moduledoc false
  alias DeltaEx.Native

  @spec app_transaction_version(DeltaEx.t(), String.t()) ::
          {:ok, integer() | nil} | {:error, DeltaEx.error_reason()}
  def app_transaction_version(table, app_id) when is_binary(app_id) do
    case Native.app_transaction_version_nif(table, app_id) do
      {:error, _} = error -> error
      nil -> {:ok, nil}
      v when is_integer(v) -> {:ok, v}
    end
  end

  @spec commit_app_transaction(DeltaEx.t(), String.t(), integer()) ::
          :ok | {:error, DeltaEx.error_reason()}
  def commit_app_transaction(table, app_id, version)
      when is_binary(app_id) and is_integer(version) do
    case Native.commit_app_transaction_nif(table, app_id, version) do
      {:error, _} = error -> error
      _ -> :ok
    end
  end
end
