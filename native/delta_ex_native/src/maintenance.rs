use crate::error;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use deltalake::protocol::checkpoints;
use deltalake::protocol::log_compaction;
use rustler::{Error, ResourceArc};

#[rustler::nif]
pub fn create_checkpoint_nif(resource: ResourceArc<DeltaTableResource>) -> Result<(), Error> {
    let table = resource.table.read().unwrap();
    RUNTIME
        .block_on(checkpoints::create_checkpoint(&table, None))
        .map_err(error::nif("Create Checkpoint"))?;
    Ok(())
}

#[rustler::nif]
pub fn cleanup_metadata_nif(resource: ResourceArc<DeltaTableResource>) -> Result<i64, Error> {
    let table = resource.table.read().unwrap();
    let deleted = RUNTIME
        .block_on(checkpoints::cleanup_metadata(&table, None))
        .map_err(error::nif("Cleanup Metadata"))?;
    Ok(deleted as i64)
}

#[rustler::nif]
pub fn update_incremental_nif(
    resource: ResourceArc<DeltaTableResource>,
    max_version: Option<i64>,
) -> Result<i64, Error> {
    let mut table = resource.table.write().unwrap();
    RUNTIME
        .block_on(table.update_incremental(max_version.map(|v| v as u64)))
        .map_err(error::nif("Update Incremental"))?;
    Ok(table.version().unwrap_or(0) as i64)
}

#[rustler::nif]
pub fn compact_logs_nif(
    resource: ResourceArc<DeltaTableResource>,
    start_version: i64,
    end_version: i64,
) -> Result<(), Error> {
    let table = resource.table.read().unwrap();
    RUNTIME
        .block_on(log_compaction::compact_logs(
            &table,
            start_version as u64,
            end_version as u64,
            None,
        ))
        .map_err(error::nif("Compact Logs"))?;
    Ok(())
}

#[rustler::nif]
pub fn generate_manifest_nif(resource: ResourceArc<DeltaTableResource>) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();
    RUNTIME
        .block_on(async {
            let new_table = table.clone().generate().await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Generate Manifest"))?;
    Ok(())
}
