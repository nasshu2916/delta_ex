use crate::error;
use crate::filesystem::table_builder;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use deltalake::kernel::MetadataValue;
use deltalake::operations::update_table_metadata::TableMetadataUpdate;
use rustler::{Error, NifMap, ResourceArc};
use std::collections::HashMap;

#[derive(NifMap)]
pub struct CommitInfoNif {
    pub version: Option<i64>,
    pub timestamp: Option<i64>,
    pub operation: Option<String>,
    pub user_id: Option<String>,
    pub user_name: Option<String>,
    pub engine_info: Option<String>,
    pub is_blind_append: Option<bool>,
    pub user_metadata: Option<String>,
}

#[derive(NifMap)]
pub struct ProtocolNif {
    pub min_reader_version: i32,
    pub min_writer_version: i32,
    pub reader_features: Option<Vec<String>>,
    pub writer_features: Option<Vec<String>>,
}

#[rustler::nif]
pub fn history_nif(
    resource: ResourceArc<DeltaTableResource>,
    limit: Option<usize>,
) -> Result<Vec<CommitInfoNif>, Error> {
    let table = resource.table.read().unwrap();

    let infos = RUNTIME
        .block_on(table.history(limit))
        .map_err(error::nif("History"))?;

    let starting_version = table.version().unwrap_or(0) as i64;

    let mut result = Vec::new();
    for (idx, info) in infos.into_iter().enumerate() {
        result.push(CommitInfoNif {
            version: Some(starting_version - idx as i64),
            timestamp: info.timestamp,
            operation: info.operation,
            user_id: info.user_id,
            user_name: info.user_name,
            engine_info: info.engine_info,
            is_blind_append: info.is_blind_append,
            user_metadata: info.user_metadata,
        });
    }
    Ok(result)
}

#[rustler::nif]
pub fn protocol_nif(resource: ResourceArc<DeltaTableResource>) -> Result<ProtocolNif, Error> {
    let table = resource.table.read().unwrap();
    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?;
    let protocol = snapshot.protocol();

    Ok(ProtocolNif {
        min_reader_version: protocol.min_reader_version(),
        min_writer_version: protocol.min_writer_version(),
        reader_features: protocol
            .reader_features()
            .map(|f| f.iter().map(ToString::to_string).collect()),
        writer_features: protocol
            .writer_features()
            .map(|f| f.iter().map(ToString::to_string).collect()),
    })
}

#[rustler::nif]
pub fn partition_columns_nif(
    resource: ResourceArc<DeltaTableResource>,
) -> Result<Vec<String>, Error> {
    let table = resource.table.read().unwrap();
    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?;
    Ok(snapshot.metadata().partition_columns().to_vec())
}

#[rustler::nif]
pub fn file_uris_nif(resource: ResourceArc<DeltaTableResource>) -> Result<Vec<String>, Error> {
    let table = resource.table.read().unwrap();
    table
        .get_file_uris()
        .map(|iter| iter.collect())
        .map_err(error::nif("File URIs"))
}

#[rustler::nif]
pub fn count_nif(resource: ResourceArc<DeltaTableResource>) -> Result<i64, Error> {
    let table = resource.table.read().unwrap();
    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?;

    let total: usize = snapshot
        .log_data()
        .iter()
        .filter_map(|f| f.num_records())
        .sum();
    Ok(total as i64)
}

#[rustler::nif]
pub fn is_delta_table_nif(uri: String, storage_options: Option<HashMap<String, String>>) -> bool {
    let builder = match table_builder(&uri, storage_options) {
        Ok(b) => b,
        Err(_) => return false,
    };

    let table = match builder.build() {
        Ok(t) => t,
        Err(_) => return false,
    };

    RUNTIME
        .block_on(table.verify_deltatable_existence())
        .unwrap_or(false)
}

#[rustler::nif]
pub fn set_table_name_nif(
    resource: ResourceArc<DeltaTableResource>,
    name: String,
) -> Result<(), Error> {
    apply_metadata_update(
        resource,
        TableMetadataUpdate {
            name: Some(name),
            description: None,
        },
    )
}

#[rustler::nif]
pub fn set_table_description_nif(
    resource: ResourceArc<DeltaTableResource>,
    description: String,
) -> Result<(), Error> {
    apply_metadata_update(
        resource,
        TableMetadataUpdate {
            name: None,
            description: Some(description),
        },
    )
}

#[rustler::nif]
pub fn set_table_properties_nif(
    resource: ResourceArc<DeltaTableResource>,
    properties: HashMap<String, String>,
    raise_if_not_exists: bool,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let new_table = table
                .clone()
                .set_tbl_properties()
                .with_properties(properties)
                .with_raise_if_not_exists(raise_if_not_exists)
                .await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Set Properties"))?;
    Ok(())
}

#[rustler::nif]
pub fn set_column_metadata_nif(
    resource: ResourceArc<DeltaTableResource>,
    field_name: String,
    metadata: HashMap<String, String>,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();
    let metadata: HashMap<String, MetadataValue> = metadata
        .into_iter()
        .map(|(k, v)| (k, MetadataValue::String(v)))
        .collect();

    RUNTIME
        .block_on(async {
            let new_table = table
                .clone()
                .update_field_metadata()
                .with_field_name(&field_name)
                .with_metadata(metadata)
                .await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Set Column Metadata"))?;
    Ok(())
}

fn apply_metadata_update(
    resource: ResourceArc<DeltaTableResource>,
    update: TableMetadataUpdate,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let new_table = table
                .clone()
                .update_table_metadata()
                .with_update(update)
                .await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Update Metadata"))?;
    Ok(())
}
