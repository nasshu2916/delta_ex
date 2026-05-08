defmodule DeltaEx.Util do
  @moduledoc false

  @typedoc """
  Mode for converting string keys returned from native readers.

  Mirrors `t:DeltaEx.keys_mode/0`. See the "Key conversion" section in the
  `DeltaEx` module documentation for the full behaviour specification.
  """
  @type keys_mode :: DeltaEx.keys_mode()

  @valid_keys_modes [:strings, :atoms, :atoms!]

  @doc """
  Returns the list of valid `:keys` option values. Used by static linters.
  """
  @spec valid_keys_modes() :: [keys_mode(), ...]
  def valid_keys_modes, do: @valid_keys_modes

  @doc """
  Normalizes the keys of a map (or every map in a list) to strings via
  `to_string/1`.

  Accepts maps with atom keys, string keys, or a mix of both. Values are left
  untouched. When given a list, each element is normalized in turn so callers
  do not need to wrap the call in `Enum.map/2`.
  """
  @spec stringify_keys(map()) :: %{String.t() => term()}
  @spec stringify_keys([map()]) :: [%{String.t() => term()}]
  def stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  def stringify_keys(list) when is_list(list) do
    Enum.map(list, &stringify_keys/1)
  end

  @doc """
  Converts the keys of a map (or every map in a list) according to `mode`.

  Accepted modes:

    * `:strings` - leave keys as-is (default behavior). The input is returned
      unchanged without traversal.
    * `:atoms` - convert string keys to atoms via `String.to_atom/1`. Use only
      when keys come from a trusted, bounded set, since atoms are not garbage
      collected.
    * `:atoms!` - convert string keys to atoms via `String.to_existing_atom/1`.
      Raises `ArgumentError` when an atom does not yet exist.

  Conversion rules:

    * Only top-level keys are converted. Values — including nested maps from
      Delta `struct` columns — are not traversed and keep their original keys.
    * Keys that are already atoms are passed through unchanged and are not
      re-validated under `:atoms!`.
  """
  @spec convert_keys([map()] | map(), keys_mode()) :: [map()] | map()
  def convert_keys(value, :strings), do: value

  def convert_keys(map, mode) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_atom(k, mode), v} end)
  end

  def convert_keys(list, mode) when is_list(list) do
    Enum.map(list, &convert_keys(&1, mode))
  end

  defp to_atom(key, _mode) when is_atom(key), do: key
  defp to_atom(key, :atoms) when is_binary(key), do: String.to_atom(key)
  defp to_atom(key, :atoms!) when is_binary(key), do: String.to_existing_atom(key)

  @doc """
  Extracts and validates the `:keys` option used by reader-style functions.

  Returns one of `:strings`, `:atoms`, or `:atoms!`. When the option is
  absent at the call site, falls back to `DeltaEx.Config.keys/0`
  (defaults to `:strings`). Raises `ArgumentError` when an unsupported
  value is provided.
  """
  @spec fetch_keys_option(keyword()) :: keys_mode()
  def fetch_keys_option(opts) when is_list(opts) do
    case Keyword.fetch(opts, :keys) do
      :error ->
        DeltaEx.Config.keys()

      {:ok, mode} when mode in @valid_keys_modes ->
        mode

      {:ok, other} ->
        raise ArgumentError,
              "invalid :keys option #{inspect(other)}, expected one of :strings, :atoms, :atoms!"
    end
  end

  @doc """
  Extracts `:storage_options` from a keyword list as a `%{String.t() => String.t()}`
  map suitable for passing to NIFs. Returns `nil` when absent or empty so the
  Rust side can skip configuring the object_store.

  Application-wide defaults configured via `DeltaEx.Config` are merged in:
  call-site keys override application-level keys with the same name.
  """
  @spec fetch_storage_options(keyword()) :: %{String.t() => String.t()} | nil
  def fetch_storage_options(opts) when is_list(opts) do
    config_map = DeltaEx.Config.storage_options()
    call_map = normalize_call_storage_options(Keyword.get(opts, :storage_options))

    case {config_map, call_map} do
      {nil, nil} -> nil
      {cfg, nil} -> cfg
      {nil, call} -> call
      {cfg, call} -> Map.merge(cfg, call)
    end
  end

  defp normalize_call_storage_options(nil), do: nil

  defp normalize_call_storage_options(map) when is_map(map) do
    if map_size(map) == 0 do
      nil
    else
      Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
    end
  end

  defp normalize_call_storage_options(other) do
    raise ArgumentError,
          "invalid :storage_options #{inspect(other)}, expected a map of String=>String"
  end
end
