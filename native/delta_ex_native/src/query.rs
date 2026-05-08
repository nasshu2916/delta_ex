use crate::error;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use crate::schema::record_batches_to_list;
use datafusion::prelude::SessionContext;
use deltalake::delta_datafusion::DeltaTableProvider;
use rustler::{Env, Error, ResourceArc, Term};
use std::sync::Arc;

#[rustler::nif]
pub fn query_sql_nif<'a>(
    env: Env<'a>,
    resource: ResourceArc<DeltaTableResource>,
    table_name: String,
    sql: String,
) -> Result<Term<'a>, Error> {
    let table = resource.table.read().unwrap();

    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?.clone();
    let provider = DeltaTableProvider::try_new(
        snapshot.snapshot().clone(),
        table.log_store(),
        Default::default(),
    )
    .map_err(error::nif("Provider"))?;

    let ctx = SessionContext::new();
    ctx.register_table(table_name.as_str(), Arc::new(provider))
        .map_err(error::nif("Register"))?;

    let batches = RUNTIME
        .block_on(async {
            let df = ctx.sql(&sql).await?;
            df.collect().await
        })
        .map_err(error::nif("Query"))?;

    Ok(record_batches_to_list(env, batches))
}
