use crate::error;
use crate::filesystem::table_builder;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use crate::schema::record_batches_to_list;
use datafusion::prelude::*;
use deltalake::delta_datafusion::DeltaTableProvider;
use rustler::{Env, Error, ResourceArc, Term};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

#[rustler::nif]
pub fn load_table_nif(
    uri: String,
    version: Option<i64>,
    storage_options: Option<HashMap<String, String>>,
) -> Result<ResourceArc<DeltaTableResource>, Error> {
    let mut builder = table_builder(&uri, storage_options).map_err(error::nif("Builder"))?;

    if let Some(v) = version {
        builder = builder.with_version(v as u64);
    }

    let table = RUNTIME
        .block_on(builder.load())
        .map_err(error::nif("DeltaLake"))?;

    Ok(ResourceArc::new(DeltaTableResource {
        table: RwLock::new(table),
    }))
}

#[rustler::nif]
pub fn version(resource: ResourceArc<DeltaTableResource>) -> i64 {
    let table = resource.table.read().unwrap();
    table.version().unwrap_or(0) as i64
}

#[rustler::nif]
pub fn files(resource: ResourceArc<DeltaTableResource>) -> Result<Vec<String>, Error> {
    let table = resource.table.read().unwrap();
    table
        .get_file_uris()
        .map(|iter| iter.collect())
        .map_err(error::nif("Files"))
}

#[rustler::nif]
pub fn to_list(env: Env, resource: ResourceArc<DeltaTableResource>) -> Result<Term, Error> {
    let table = resource.table.read().unwrap();

    let ctx = SessionContext::new();
    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?.clone();
    let provider = DeltaTableProvider::try_new(
        snapshot.snapshot().clone(),
        table.log_store(),
        Default::default(),
    )
    .map_err(error::nif("Provider"))?;

    ctx.register_table("t", Arc::new(provider))
        .map_err(error::nif("DataFusion"))?;

    let df = RUNTIME
        .block_on(ctx.sql("SELECT * FROM t"))
        .map_err(error::nif("Query"))?;

    let batches = RUNTIME
        .block_on(df.collect())
        .map_err(error::nif("Collect"))?;

    Ok(record_batches_to_list(env, batches))
}
