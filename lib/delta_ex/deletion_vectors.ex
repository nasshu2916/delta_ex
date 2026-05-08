defmodule DeltaEx.DeletionVectors do
  @moduledoc false
  alias DeltaEx.Native

  @spec deletion_vectors(DeltaEx.t()) :: {:ok, [map()]} | {:error, DeltaEx.error_reason()}
  def deletion_vectors(table) do
    case Native.deletion_vectors_nif(table) do
      {:error, _} = error -> error
      list when is_list(list) -> {:ok, list}
    end
  end
end
