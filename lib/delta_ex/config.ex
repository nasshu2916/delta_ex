defmodule DeltaEx.Config do
  @moduledoc """
  Application-level defaults for DeltaEx options.

  All public reader/writer functions accept per-call options. When a given
  option is not supplied at the call site, DeltaEx falls back to the values
  declared here via `Application` config. Per-call options always take
  precedence; for `:storage_options` the call-site map is merged on top of
  the application-wide map (call-site keys override).

  ## Example

      # config/runtime.exs
      config :delta_ex,
        keys: :atoms,
        storage_options: %{"AWS_REGION" => "ap-northeast-1"},
        writer: [target_file_size: 134_217_728, write_batch_size: 8192],
        vacuum: [retention_hours: 168, dry_run: true],
        query: [table_name: "t"]

  ## Recognised keys

    * `:keys` — default `:keys` mode for reader-style functions
      (`to_list/2`, `load_cdf/2`, `query/3`). Must be one of `:strings`
      (default), `:atoms`, or `:atoms!`. See the "Key conversion" section
      in `DeltaEx`.
    * `:storage_options` — `%{String.t() => String.t()}` map applied to
      every NIF call that talks to object storage. Per-call
      `:storage_options` are merged on top.
    * `:writer` — keyword list of writer defaults. Recognised keys:
      `:target_file_size`, `:write_batch_size`.
    * `:vacuum` — keyword list of vacuum defaults. Recognised keys:
      `:retention_hours`, `:dry_run`.
    * `:query` — keyword list of query defaults. Recognised keys:
      `:table_name`.

  Invalid values raise `ArgumentError` on first access — this is intentional
  so misconfiguration surfaces early rather than silently breaking later
  calls.
  """

  @valid_keys_modes [:strings, :atoms, :atoms!]

  @typedoc "Writer-related defaults."
  @type writer_defaults :: [
          {:target_file_size, pos_integer()}
          | {:write_batch_size, pos_integer()}
        ]

  @typedoc "Vacuum-related defaults."
  @type vacuum_defaults :: [
          {:retention_hours, non_neg_integer()}
          | {:dry_run, boolean()}
        ]

  @typedoc "Query-related defaults."
  @type query_defaults :: [{:table_name, String.t()}]

  @doc """
  Returns the configured default `:keys` mode. Defaults to `:strings`.
  """
  @spec keys() :: DeltaEx.keys_mode()
  def keys do
    case Application.get_env(:delta_ex, :keys, :strings) do
      mode when mode in @valid_keys_modes ->
        mode

      other ->
        raise ArgumentError,
              "invalid application env :delta_ex, :keys = #{inspect(other)}, " <>
                "expected one of :strings, :atoms, :atoms!"
    end
  end

  @doc """
  Returns the configured default `:storage_options` map, or `nil` when
  unset/empty. The returned map has stringified keys and values.
  """
  @spec storage_options() :: %{String.t() => String.t()} | nil
  def storage_options do
    case Application.get_env(:delta_ex, :storage_options) do
      nil ->
        nil

      map when is_map(map) and map_size(map) == 0 ->
        nil

      map when is_map(map) ->
        Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)

      other ->
        raise ArgumentError,
              "invalid application env :delta_ex, :storage_options = #{inspect(other)}, " <>
                "expected a map of String=>String"
    end
  end

  @doc "Returns the configured `:writer` keyword list (default `[]`)."
  @spec writer() :: writer_defaults()
  def writer, do: get_keyword!(:writer)

  @doc "Returns the configured `:vacuum` keyword list (default `[]`)."
  @spec vacuum() :: vacuum_defaults()
  def vacuum, do: get_keyword!(:vacuum)

  @doc "Returns the configured `:query` keyword list (default `[]`)."
  @spec query() :: query_defaults()
  def query, do: get_keyword!(:query)

  defp get_keyword!(key) do
    case Application.get_env(:delta_ex, key, []) do
      kw when is_list(kw) ->
        kw

      other ->
        raise ArgumentError,
              "invalid application env :delta_ex, :#{key} = #{inspect(other)}, " <>
                "expected a keyword list"
    end
  end
end
