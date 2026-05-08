use datafusion::datasource::memory::MemTable;
use datafusion::prelude::*;
use deltalake::delta_datafusion::DeltaTableProvider;
use deltalake::{DeltaTable, DeltaTableError};
use std::sync::Arc;

/// Build a DataFusion session whose target table mirrors the Delta table's Arrow schema.
/// Returns the context plus a DataFrame that exposes the proper DFSchema for predicate parsing.
pub fn target_session(table: &DeltaTable) -> Result<(SessionContext, DataFrame), DeltaTableError> {
    let snapshot = table.snapshot()?;
    let provider = DeltaTableProvider::try_new(
        snapshot.snapshot().clone(),
        table.log_store(),
        Default::default(),
    )
    .map_err(|e| DeltaTableError::Generic(e.to_string()))?;
    let arrow_schema = datafusion::datasource::TableProvider::schema(&provider);

    let ctx = SessionContext::new();
    let target_provider = Arc::new(
        MemTable::try_new(arrow_schema, vec![vec![]])
            .map_err(|e| DeltaTableError::Generic(e.to_string()))?,
    );
    let df = ctx
        .read_table(target_provider)
        .map_err(|e| DeltaTableError::Generic(e.to_string()))?;
    Ok((ctx, df))
}
