# Development of DeltaEx

This document outlines how to set up your environment for developing DeltaEx and how to contribute changes.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. (TODO: Add link to CoC if available)

## How Can I Contribute?

### Reporting Bugs

- **Search first**: Check if the bug has already been reported in the issues.
- **Be specific**: Include your Elixir/Erlang version, OS, and a minimal reproducible example.

### Suggesting Enhancements

- **Explain the use case**: Why is this feature needed?
- **Provide examples**: How should the API look?

### Pull Requests

1. **Fork the repo** and create your branch from `main`.
2. **Add tests**: If you're adding a feature or fixing a bug, please add tests.
3. **Rust formatting & tests**: If you touch the `native/` code, run `cargo fmt`, `cargo clippy`, and `cargo test`.
4. **Static Analysis**: Run `mix credo` and `mix dialyzer` to ensure code quality.
5. **Elixir formatting**: Run `mix format`.
6. **Update documentation**: If you change the API, update the docs and README.

## Development Setup

1. Install Elixir and Rust.
2. Clone the repository.
3. Run `mix deps.get`.
4. Run `mix compile` to build the NIF.
5. Run `mix test` to ensure everything is working.
6. Alternatively, run `mix ci` to run all checks (format, credo, dialyzer, and tests).
7. Use `mix fix` to automatically format code and fix some linting issues.

## Rust Development

The core logic of DeltaEx is implemented in Rust as a NIF.

### Dependencies

Rust dependencies are managed via `Cargo`. They are automatically fetched during `mix compile`, but you can fetch them manually:

```bash
cd native/delta_ex_native
cargo fetch
```

### Manual Compilation

To build the Rust NIF manually (useful for checking for compilation errors):

```bash
cd native/delta_ex_native
cargo build
```

### Testing

You can run Rust-specific tests (if any) using:

```bash
cd native/delta_ex_native
cargo test
```

### Formatting

Always format your Rust code before submitting a PR:

```bash
cd native/delta_ex_native
cargo fmt
```

## Cloud Storage Integration Tests

Tests against S3 (and S3-compatible backends) are tagged `:s3` and excluded
from `mix test` by default. They run end-to-end CRUD against a local MinIO
instance launched via the bundled `docker-compose.yml`.

### Quick start (MinIO via docker-compose)

```bash
# 1. Start MinIO and create the test bucket.
docker compose up -d minio minio-setup

# 2. Run the S3 integration suite.
mix test --include s3

# 3. Tear down.
docker compose down -v
```

The compose file binds:

- `http://127.0.0.1:9000` — S3 API
- `http://127.0.0.1:9001` — MinIO web console (`minioadmin` / `minioadmin`)

### Pointing the suite at a different endpoint

`test/support/s3_helper.ex` reads connection details from environment
variables, so the same suite can target LocalStack, real AWS, or another
MinIO deployment:

| Variable | Default | Purpose |
| --- | --- | --- |
| `DELTA_EX_S3_ENDPOINT` | `http://127.0.0.1:9000` | S3 API endpoint URL |
| `DELTA_EX_S3_BUCKET` | `delta-ex-test` | Bucket used for test tables |
| `AWS_REGION` | `us-east-1` | Region forwarded to delta-rs |
| `AWS_ACCESS_KEY_ID` | `minioadmin` | Access key |
| `AWS_SECRET_ACCESS_KEY` | `minioadmin` | Secret key |

### Using `:storage_options` in application code

URI-based DeltaEx functions accept a `:storage_options` keyword that maps to
the underlying object_store configuration (AWS, GCS, Azure keys are all
forwarded as-is by delta-rs):

```elixir
opts = [
  storage_options: %{
    "AWS_ENDPOINT_URL" => "https://s3.us-east-1.amazonaws.com",
    "AWS_REGION" => "us-east-1",
    "AWS_ACCESS_KEY_ID" => System.fetch_env!("AWS_ACCESS_KEY_ID"),
    "AWS_SECRET_ACCESS_KEY" => System.fetch_env!("AWS_SECRET_ACCESS_KEY")
  }
]

:ok = DeltaEx.insert("s3://my-bucket/events", rows, opts)
{:ok, table} = DeltaEx.load_table("s3://my-bucket/events", opts)
```

Functions accepting `:storage_options`: `load_table/2`, `insert/3`, `merge/4`,
`delete/3`, `update/4`, `convert_to_delta/2`, `delta_table?/2`.

### Notes for S3 backends

- delta-rs requires a locking provider for S3 writes. MinIO does not provide
  one, so the tests set `AWS_S3_ALLOW_UNSAFE_RENAME=true` — acceptable for
  single-writer dev/CI but **never** in production.
- Plain HTTP endpoints need `AWS_ALLOW_HTTP=true`.
- For real AWS, prefer DynamoDB-based locking by setting
  `AWS_S3_LOCKING_PROVIDER=dynamodb` plus the related table envs.

## Questions?

Feel free to open an issue or start a discussion!
