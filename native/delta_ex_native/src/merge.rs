use crate::error;
use crate::filesystem::table_builder;
use crate::runtime::RUNTIME;
use crate::schema::terms_to_record_batch;
use datafusion::prelude::*;
use rustler::{Error, Term};
use std::collections::HashMap;
use std::sync::Arc;

#[rustler::nif]
pub fn merge_nif(
    uri: String,
    data: Term,
    predicate: String,
    storage_options: Option<HashMap<String, String>>,
) -> Result<(), Error> {
    let batch = terms_to_record_batch(data)?;

    RUNTIME
        .block_on(async {
            let mut table = table_builder(&uri, storage_options)?.build()?;
            table.load().await?;

            let ctx = SessionContext::new();

            // Get Arrow schema from Delta table
            let snapshot = table.snapshot()?;
            let provider = deltalake::delta_datafusion::DeltaTableProvider::try_new(
                snapshot.snapshot().clone(),
                table.log_store(),
                Default::default(),
            )
            .map_err(error::delta("Provider"))?;
            let arrow_schema = datafusion::datasource::TableProvider::schema(&provider);

            // Register dummy tables to get the combined schema for predicate parsing
            let target_provider = Arc::new(
                datafusion::datasource::memory::MemTable::try_new(
                    arrow_schema.clone(),
                    vec![vec![]],
                )
                .map_err(error::delta("Target MemTable"))?,
            );
            ctx.register_table("target", target_provider)
                .map_err(error::delta("Register target"))?;

            let source_provider = Arc::new(
                datafusion::datasource::memory::MemTable::try_new(batch.schema(), vec![vec![]])
                    .map_err(error::delta("Source MemTable"))?,
            );
            ctx.register_table("source", source_provider)
                .map_err(error::delta("Register source"))?;

            let df = ctx
                .sql("SELECT * FROM target CROSS JOIN source")
                .await
                .map_err(error::delta("Build merge schema"))?;
            let combined_schema = df.schema();

            let expr = ctx
                .state()
                .create_logical_expr(&predicate, combined_schema)
                .map_err(error::delta("Predicate"))?;

            let source_df = ctx.read_batch(batch).map_err(error::delta("Read batch"))?;

            let (_table, _metrics) = table
                .merge(source_df, expr)
                .with_source_alias("source")
                .with_target_alias("target")
                .when_matched_update(|update| {
                    let mut update = update;
                    for field in arrow_schema.fields() {
                        update =
                            update.update(field.name(), col(format!("source.{}", field.name())));
                    }
                    update
                })?
                .when_not_matched_insert(|insert| {
                    let mut insert = insert;
                    for field in arrow_schema.fields() {
                        insert = insert.set(field.name(), col(format!("source.{}", field.name())));
                    }
                    insert
                })?
                .await?;

            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Merge"))?;

    Ok(())
}
