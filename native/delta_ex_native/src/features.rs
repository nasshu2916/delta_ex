use crate::error;
use crate::resource::DeltaTableResource;
use crate::runtime::RUNTIME;
use deltalake::kernel::TableFeatures;
use rustler::{Error, ResourceArc};

#[rustler::nif]
pub fn add_feature_nif(
    resource: ResourceArc<DeltaTableResource>,
    feature_name: String,
) -> Result<(), Error> {
    let mut table = resource.table.write().unwrap();

    let feature = match feature_name.as_str() {
        "deletionVectors" => TableFeatures::DeletionVectors,
        "columnMapping" => TableFeatures::ColumnMapping,
        "changeDataFeed" => TableFeatures::ChangeDataFeed,
        "v2Checkpoint" => TableFeatures::V2Checkpoint,
        _ => {
            return Err(error::nif_msg(format!(
                "Unsupported or unknown feature: {}",
                feature_name
            )))
        }
    };

    RUNTIME
        .block_on(async {
            let new_table = table
                .clone()
                .add_feature()
                .with_feature(feature)
                .with_allow_protocol_versions_increase(true)
                .await?;
            *table = new_table;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Add Feature"))?;

    Ok(())
}
