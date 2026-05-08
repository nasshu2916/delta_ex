use crate::error;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use arrow::ipc::writer::StreamWriter;
use datafusion::prelude::*;
use deltalake::delta_datafusion::DeltaTableProvider;
use rustler::{Binary, Env, Error, NewBinary, ResourceArc};
use std::sync::Arc;

#[rustler::nif]
pub fn to_arrow_ipc_nif<'a>(
    env: Env<'a>,
    resource: ResourceArc<DeltaTableResource>,
) -> Result<Binary<'a>, Error> {
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

    let schema = df.schema().as_arrow().clone();

    let batches = RUNTIME
        .block_on(df.collect())
        .map_err(error::nif("Collect"))?;

    let mut buffer: Vec<u8> = Vec::new();
    {
        let mut writer =
            StreamWriter::try_new(&mut buffer, &schema).map_err(error::nif("Arrow IPC Writer"))?;
        for batch in &batches {
            writer.write(batch).map_err(error::nif("Arrow IPC Write"))?;
        }
        writer.finish().map_err(error::nif("Arrow IPC Finish"))?;
    }

    let mut bin = NewBinary::new(env, buffer.len());
    bin.as_mut_slice().copy_from_slice(&buffer);
    Ok(bin.into())
}
