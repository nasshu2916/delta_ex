defmodule DeltaEx.Arrow do
  @moduledoc false
  alias DeltaEx.Native

  @spec to_arrow_ipc(DeltaEx.t()) :: {:ok, binary()} | {:error, DeltaEx.error_reason()}
  def to_arrow_ipc(table) do
    case Native.to_arrow_ipc_nif(table) do
      {:error, _} = error -> error
      bin when is_binary(bin) -> {:ok, bin}
    end
  end
end
