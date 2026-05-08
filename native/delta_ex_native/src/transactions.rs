use crate::error;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use deltalake::kernel::transaction::CommitBuilder;
use deltalake::kernel::Action;
use deltalake::kernel::Transaction;
use deltalake::protocol::{DeltaOperation, OutputMode};
use rustler::{Error, ResourceArc};

#[rustler::nif]
pub fn app_transaction_version_nif(
    resource: ResourceArc<DeltaTableResource>,
    app_id: String,
) -> Result<Option<i64>, Error> {
    let table = resource.table.read().unwrap();

    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?;
    let log_store = table.log_store();

    RUNTIME
        .block_on(snapshot.transaction_version(log_store.as_ref(), app_id))
        .map_err(error::nif("App Transaction"))
}

#[rustler::nif]
pub fn commit_app_transaction_nif(
    resource: ResourceArc<DeltaTableResource>,
    app_id: String,
    version: i64,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            {
                let snapshot = table.snapshot()?;
                let log_store = table.log_store();
                let txn = Transaction::new(&app_id, version);

                CommitBuilder::default()
                    .with_actions(vec![Action::Txn(txn)])
                    .build(
                        Some(snapshot),
                        log_store,
                        DeltaOperation::StreamingUpdate {
                            output_mode: OutputMode::Append,
                            query_id: app_id.clone(),
                            epoch_id: version,
                        },
                    )
                    .await?;
            }

            table.update_incremental(None).await?;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Commit App Transaction"))?;

    Ok(())
}
