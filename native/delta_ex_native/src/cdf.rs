use crate::error;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use crate::schema::record_batches_to_list;
use datafusion::prelude::SessionContext;
use deltalake::delta_datafusion::DeltaCdfTableProvider;
#[allow(deprecated)]
use deltalake::DeltaOps;
use rustler::{Env, Error, ResourceArc, Term};
use std::sync::Arc;

#[allow(deprecated)]
#[rustler::nif]
pub fn load_cdf_nif<'a>(
    env: Env<'a>,
    resource: ResourceArc<DeltaTableResource>,
    starting_version: Option<i64>,
    ending_version: Option<i64>,
    starting_timestamp: Option<String>,
    ending_timestamp: Option<String>,
    allow_out_of_range: bool,
) -> Result<Term<'a>, Error> {
    let table = resource.table.read().unwrap();

    let batches = RUNTIME
        .block_on(async {
            let mut builder = DeltaOps::from(table.clone()).load_cdf();
            if let Some(v) = starting_version {
                builder = builder.with_starting_version(v as u64);
            }
            if let Some(v) = ending_version {
                builder = builder.with_ending_version(v as u64);
            }
            if let Some(ts) = starting_timestamp {
                let dt = chrono::DateTime::parse_from_rfc3339(&ts)
                    .map_err(error::delta("Invalid starting_timestamp"))?
                    .with_timezone(&chrono::Utc);
                builder = builder.with_starting_timestamp(dt);
            }
            if let Some(ts) = ending_timestamp {
                let dt = chrono::DateTime::parse_from_rfc3339(&ts)
                    .map_err(error::delta("Invalid ending_timestamp"))?
                    .with_timezone(&chrono::Utc);
                builder = builder.with_ending_timestamp(dt);
            }
            if allow_out_of_range {
                builder = builder.with_allow_out_of_range();
            }

            let provider = DeltaCdfTableProvider::try_new(builder)?;

            let ctx = SessionContext::new();
            let df = ctx.read_table(Arc::new(provider))?;
            df.collect().await.map_err(error::delta("CDF Collect"))
        })
        .map_err(error::nif("Load CDF"))?;

    Ok(record_batches_to_list(env, batches))
}
