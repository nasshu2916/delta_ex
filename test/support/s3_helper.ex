defmodule DeltaEx.Test.S3Helper do
  @moduledoc false
  # Helpers for cloud-storage integration tests against an S3-compatible
  # endpoint (MinIO via docker-compose by default). Reads connection details
  # from environment variables so CI can point tests at a different endpoint
  # (e.g. real AWS, LocalStack) without code changes.

  @default_endpoint "http://127.0.0.1:9000"
  @default_region "us-east-1"
  @default_bucket "delta-ex-test"
  @default_access_key "minioadmin"
  @default_secret_key "minioadmin"

  @doc "Storage options map passed to DeltaEx URI-based functions."
  def storage_options do
    %{
      "AWS_ENDPOINT_URL" => endpoint(),
      "AWS_REGION" => region(),
      "AWS_ACCESS_KEY_ID" => access_key(),
      "AWS_SECRET_ACCESS_KEY" => secret_key(),
      "AWS_ALLOW_HTTP" => "true",
      # MinIO does not support DynamoDB-based locking, but delta-rs requires
      # a locking provider for S3 writes. The unsafe-rename provider is
      # acceptable for tests against a single-writer dev backend.
      "AWS_S3_ALLOW_UNSAFE_RENAME" => "true"
    }
  end

  @doc "Builds a unique `s3://<bucket>/<prefix>` URI for a single test."
  def unique_uri(prefix) do
    suffix = System.unique_integer([:positive, :monotonic])
    "s3://#{bucket()}/#{prefix}-#{suffix}"
  end

  @doc """
  Returns true when the configured S3 endpoint is reachable. Tests skip
  themselves when this returns false so missing local infra produces a
  clear skip rather than a hard failure.
  """
  def reachable? do
    uri = URI.parse(endpoint())

    case :gen_tcp.connect(String.to_charlist(uri.host || "localhost"), uri.port || 9000, [], 1000) do
      {:ok, sock} ->
        :gen_tcp.close(sock)
        true

      _ ->
        false
    end
  end

  defp endpoint, do: System.get_env("DELTA_EX_S3_ENDPOINT", @default_endpoint)
  defp region, do: System.get_env("AWS_REGION", @default_region)
  defp bucket, do: System.get_env("DELTA_EX_S3_BUCKET", @default_bucket)
  defp access_key, do: System.get_env("AWS_ACCESS_KEY_ID", @default_access_key)
  defp secret_key, do: System.get_env("AWS_SECRET_ACCESS_KEY", @default_secret_key)
end
