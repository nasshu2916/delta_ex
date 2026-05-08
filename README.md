# DeltaEx

**DeltaEx** is an Elixir wrapper for [Delta Lake](https://delta.io/), built on top of the native Rust implementation [delta-rs](https://github.com/delta-io/delta-rs) using [Rustler](https://github.com/rusterlium/rustler).

## Features

- **Native Performance**: Leverages Rust's memory safety and performance via NIFs.
- **Engine Agnostic**: Interact with Delta tables without requiring Apache Spark or the JVM.
- **Cloud Native**: Supports AWS S3, Azure Data Lake Storage (ADLS) Gen2, Google Cloud Storage (GCS), and local file systems.
- **Apache Arrow Integration**: Seamless data interoperability using the Arrow ecosystem.
- **Time Travel**: Query specific versions of your data or view table history.
- **Table Maintenance**: Support for `VACUUM`, `OPTIMIZE`, and checkpointing.

## API Compatibility Matrix

| Operation | delta-rs | DeltaEx | Description | Notes |
| :--- | :---: | :---: | :--- | :--- |
| **Create** | ✅ | ✅ | Create a new table | `DeltaEx.insert/2` |
| **Read** | ✅ | ✅ | Read data from a table | `DeltaEx.to_list/1` |
| **Write / Append** | ✅ | ✅ | Write data to a table | `DeltaEx.insert/2` |
| **Vacuum** | ✅ | ✅ | Remove unused files | `DeltaEx.vacuum/2` |
| **Optimize - compaction** | ✅ | ✅ | Compact small files | `DeltaEx.optimize/1` |
| **Optimize - Z-order** | ✅ | ✅ | Place similar data together | `DeltaEx.optimize/2` |
| **Delete - predicates** | ✅ | ✅ | Delete data based on a predicate | `DeltaEx.delete/2` |
| **Merge (Upsert)** | ✅ | ✅ | Merge source data into target | `DeltaEx.merge/3` |
| **Update** | ✅ | ✅ | Update values in a table | `DeltaEx.update/3` |
| **Time Travel** | ✅ | ✅ | Query specific versions | `DeltaEx.load_table/2` |
| **Restore** | ✅ | ✅ | Restore to previous state | `DeltaEx.restore/2` |
| **Convert to Delta** | ✅ | ✅ | Convert parquet to delta | `DeltaEx.convert_to_delta/1` |
| **FS check** | ✅ | ✅ | Remove corrupted files | `DeltaEx.filesystem_check/1` |
| **Add Column** | ✅ | ✅ | Add new columns | `DeltaEx.add_column/4` |
| **Add Feature** | ✅ | ✅ | Enable table features | `DeltaEx.add_feature/2` |
| **Constraints** | ✅ | ✅ | Set delta constraints | `DeltaEx.add_constraint/3` |
| **Metadata** | ✅ | ✅ | Get table version or files | `DeltaEx.version/1`, `DeltaEx.files/1` |
| **Cloud Support** | ✅ | ✅ | S3, GCS, Azure, and local | Native storage |
| **History** | ✅ | ✅ | Get commit history | `DeltaEx.history/2` |
| **Protocol** | ✅ | ✅ | Get reader/writer protocol versions | `DeltaEx.protocol/1` |
| **Partitions** | ✅ | ✅ | List partition columns | `DeltaEx.partition_columns/1` |
| **File URIs** | ✅ | ✅ | Get absolute parquet file URIs | `DeltaEx.file_uris/1` |
| **Count** | ✅ | ✅ | Approximate row count from statistics | `DeltaEx.count/1` |
| **Is Delta Table** | ✅ | ✅ | Check whether a path is a Delta table | `DeltaEx.delta_table?/1` |
| **To Arrow IPC** | ✅ | ✅ | Export table data as Arrow IPC stream bytes | `DeltaEx.to_arrow_ipc/1` |
| **Load CDF** | ✅ | ✅ | Read Change Data Feed | `DeltaEx.load_cdf/2` |
| **Deletion Vectors** | ✅ | ✅ | Get deletion vectors of data files | `DeltaEx.deletion_vectors/1` |
| **Create Checkpoint** | ✅ | ✅ | Create a checkpoint | `DeltaEx.create_checkpoint/1` |
| **Cleanup Metadata** | ✅ | ✅ | Remove expired log files | `DeltaEx.cleanup_metadata/1` |
| **Compact Logs** | ✅ | ✅ | Compact transaction logs | `DeltaEx.compact_logs/2` |
| **Set Table Properties** | ✅ | ✅ | Set table-level properties | `DeltaEx.set_table_properties/3` |
| **Set Table Name** | ✅ | ✅ | Rename the table | `DeltaEx.set_table_name/2` |
| **Set Table Description** | ✅ | ✅ | Set table description | `DeltaEx.set_table_description/2` |
| **Set Column Metadata** | ✅ | ✅ | Update column metadata | `DeltaEx.set_column_metadata/3` |
| **Update Incremental** | ✅ | ✅ | Incremental update | `DeltaEx.update_incremental/2` |
| **Generate Manifest** | ✅ | ✅ | Generate symlink manifest for external engines | `DeltaEx.generate_manifest/1` |
| **Query Builder** | ✅ | ✅ | DataFusion-based SQL query | `DeltaEx.query/3` |
| **Writer / Commit Properties** | ✅ | ✅ | `:app_metadata`, `:target_file_size`, `:write_batch_size` on insert | `DeltaEx.insert/3` |
| **Transactions** | ✅ | ✅ | Application transaction (idempotent commits) | `DeltaEx.commit_app_transaction/3`, `DeltaEx.app_transaction_version/2` |

## 📦 Installation

Add `delta_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:delta_ex, git: "https://github.com/nasshu2916/delta_ex.git", branch: "main"}
  ]
end
```

## 🛠 Usage

> [!NOTE]
> This library is under active development. Some APIs may change.

### Loading a Table

```elixir
# Load a Delta table from S3
{:ok, table} = DeltaEx.load_table("s3://my-bucket/my-table")

# Get table version
version = DeltaEx.version(table)
IO.puts("Current table version: #{version}")
```

### Reading Data

```elixir
# Read table as a list of maps (string keys, default)
data = DeltaEx.to_list(table)

# Return atom keys (similar to Jason's `keys: :atoms` option)
data = DeltaEx.to_list(table, keys: :atoms)

# Use existing atoms only (raises ArgumentError when an atom is not yet known)
data = DeltaEx.to_list(table, keys: :atoms!)
```

The `:keys` option (`:strings` (default) / `:atoms` / `:atoms!`) is also
supported by `DeltaEx.query/3` and `DeltaEx.load_cdf/2`. Any other value
raises `ArgumentError` at runtime.

### Writing Data

```elixir
data = [
  %{"id" => 1, "name" => "Alice", "age" => 30},
  %{"id" => 2, "name" => "Bob", "age" => 25}
]

# Insert data (appends to existing table)
:ok = DeltaEx.insert("path/to/table", data)
```

### Merge (Upsert)

```elixir
merge_data = [
  %{"id" => 2, "name" => "Bob Updated", "age" => 26}, # Update
  %{"id" => 3, "name" => "Charlie", "age" => 20}      # Insert
]

# Merge source data into target table using a SQL predicate
:ok = DeltaEx.merge("path/to/table", merge_data, "target.id = source.id")
```

### Update

```elixir
# Update values in the table based on a predicate
# The updates parameter is a map of column names to SQL expressions
:ok = DeltaEx.update("path/to/table", %{"age" => "age + 1"}, "id > 10")
:ok = DeltaEx.update("path/to/table", %{"status" => "'active'"}, "last_login > '2023-01-01'")
```

### Delete

```elixir
# Delete rows based on a SQL predicate
:ok = DeltaEx.delete("path/to/table", "age > 30")
```

### Time Travel

```elixir
# Load a specific version
{:ok, old_table} = DeltaEx.load_table("path/to/table", version: 5)
```

### Restore

```elixir
# Restore a table to a previous version
:ok = DeltaEx.restore(table, version: 5)

# Restore a table to a specific timestamp
:ok = DeltaEx.restore(table, datetime: "2023-01-01T00:00:00Z")
```

### Constraints

```elixir
# Add a check constraint
:ok = DeltaEx.add_constraint(table, "valid_age", "age >= 0")

# Drop a check constraint
:ok = DeltaEx.drop_constraint(table, "valid_age")
```

### Add Feature

```elixir
# Enable deletion vectors
:ok = DeltaEx.add_feature(table, "deletionVectors")

# Enable Change Data Feed
:ok = DeltaEx.add_feature(table, "changeDataFeed")
```

### FS check

```elixir
# Remove corrupted files (files in log but missing from storage)
:ok = DeltaEx.filesystem_check(table)
```

## Development

For detailed setup and development guidelines, see [DEVELOPMENT.md](DEVELOPMENT.md).

### Quick Start

To compile the NIF:

```bash
mix compile
```

To run tests:

```bash
mix test
```
