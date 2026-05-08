use crate::error;
use crate::expressions::target_session;
use crate::filesystem::table_builder;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use crate::schema::parse_delta_data_type;
use deltalake::kernel::StructField;
use deltalake::operations::optimize::OptimizeType;
use rustler::{Error, ResourceArc};
use std::collections::HashMap;
use std::sync::RwLock;

#[rustler::nif]
pub fn delete_nif(
    uri: String,
    predicate: String,
    storage_options: Option<HashMap<String, String>>,
) -> Result<(), Error> {
    RUNTIME
        .block_on(async {
            let mut table = table_builder(&uri, storage_options)?.build()?;
            table.load().await?;

            let (ctx, df) = target_session(&table)?;
            let schema = df.schema();
            let expr = ctx
                .state()
                .create_logical_expr(&predicate, schema)
                .map_err(error::delta("Predicate"))?;

            table.delete().with_predicate(expr).await?;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Delete"))?;

    Ok(())
}

#[rustler::nif]
pub fn update_nif(
    uri: String,
    updates: HashMap<String, String>,
    predicate: String,
    storage_options: Option<HashMap<String, String>>,
) -> Result<(), Error> {
    RUNTIME
        .block_on(async {
            let mut table = table_builder(&uri, storage_options)?.build()?;
            table.load().await?;

            let (ctx, df) = target_session(&table)?;
            let schema = df.schema();

            let mut update_builder = table.update();

            if !predicate.is_empty() {
                let expr = ctx
                    .state()
                    .create_logical_expr(&predicate, schema)
                    .map_err(error::delta("Predicate"))?;
                update_builder = update_builder.with_predicate(expr);
            }

            for (column, expression) in updates {
                let expr = ctx
                    .state()
                    .create_logical_expr(&expression, schema)
                    .map_err(|e| {
                        deltalake::DeltaTableError::Generic(format!(
                            "Update expression for column '{}': {}",
                            column, e
                        ))
                    })?;
                update_builder = update_builder.with_update(column, expr);
            }

            update_builder.await?;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Update"))?;

    Ok(())
}

#[rustler::nif]
pub fn vacuum_nif(
    resource: ResourceArc<DeltaTableResource>,
    retention_hours: Option<u64>,
    dry_run: bool,
) -> Result<Vec<String>, Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let mut vacuum_op = table.clone().vacuum();
            if let Some(h) = retention_hours {
                vacuum_op = vacuum_op.with_retention_period(chrono::Duration::hours(h as i64));
            }
            vacuum_op = vacuum_op.with_dry_run(dry_run);

            let (new_table, result) = vacuum_op.await?;
            *table = new_table;
            Ok::<Vec<String>, deltalake::DeltaTableError>(vec![format!(
                "Deleted {} files",
                result.files_deleted.len()
            )])
        })
        .map_err(error::nif("Vacuum"))
}

#[rustler::nif]
pub fn optimize_nif(
    resource: ResourceArc<DeltaTableResource>,
    z_order_columns: Option<Vec<String>>,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let mut optimize_op = table.clone().optimize();
            if let Some(cols) = z_order_columns {
                optimize_op = optimize_op.with_type(OptimizeType::ZOrder(cols));
            }
            let (new_table, _) = optimize_op.await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Optimize"))
}

#[rustler::nif]
pub fn filesystem_check_nif(resource: ResourceArc<DeltaTableResource>) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let (new_table, _metrics) = table.clone().filesystem_check().await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("FileSystemCheck"))?;

    Ok(())
}

#[rustler::nif]
pub fn restore_nif(
    resource: ResourceArc<DeltaTableResource>,
    version: Option<i64>,
    datetime: Option<String>,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let mut builder = table.clone().restore();
            if let Some(v) = version {
                builder = builder.with_version_to_restore(v as u64);
            } else if let Some(dt_str) = datetime {
                let dt = chrono::DateTime::parse_from_rfc3339(&dt_str)
                    .map_err(error::delta("Invalid datetime"))?
                    .with_timezone(&chrono::Utc);
                builder = builder.with_datetime_to_restore(dt);
            } else {
                return Err(deltalake::DeltaTableError::Generic(
                    "Either version or datetime must be provided".to_string(),
                ));
            }

            let (new_table, _metrics) = builder.await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Restore"))?;

    Ok(())
}

#[rustler::nif]
pub fn convert_to_delta_nif(
    uri: String,
    storage_options: Option<HashMap<String, String>>,
) -> Result<ResourceArc<DeltaTableResource>, Error> {
    let url = crate::filesystem::parse_uri(&uri).map_err(error::nif_msg)?;

    RUNTIME
        .block_on(async {
            let mut convert = deltalake::operations::convert_to_delta::ConvertToDeltaBuilder::new()
                .with_location(url.to_string());
            if let Some(opts) = storage_options {
                if !opts.is_empty() {
                    convert = convert.with_storage_options(opts);
                }
            }
            let table = convert.await?;

            Ok::<ResourceArc<DeltaTableResource>, deltalake::DeltaTableError>(ResourceArc::new(
                DeltaTableResource {
                    table: RwLock::new(table),
                },
            ))
        })
        .map_err(error::nif("Convert"))
}

#[rustler::nif]
pub fn add_column_nif(
    resource: ResourceArc<DeltaTableResource>,
    column_name: String,
    data_type: String,
    nullable: bool,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();
    let dtype = parse_delta_data_type(&data_type).map_err(error::nif_msg)?;
    let field = StructField::new(column_name, dtype, nullable);

    RUNTIME
        .block_on(async {
            let new_table = table.clone().add_columns().with_fields(vec![field]).await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Add Column"))?;

    Ok(())
}

#[rustler::nif]
pub fn add_constraint_nif(
    resource: ResourceArc<DeltaTableResource>,
    name: String,
    expression: String,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let new_table = table
                .clone()
                .add_constraint()
                .with_constraint(name, expression)
                .await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Add Constraint"))?;

    Ok(())
}

#[rustler::nif]
pub fn drop_constraint_nif(
    resource: ResourceArc<DeltaTableResource>,
    name: String,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    RUNTIME
        .block_on(async {
            let new_table = table
                .clone()
                .drop_constraints()
                .with_constraint(name)
                .await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Drop Constraint"))?;

    Ok(())
}
