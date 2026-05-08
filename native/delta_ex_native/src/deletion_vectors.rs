use crate::error;
use crate::resource::DeltaTableResource;
use rustler::{Error, NifMap, ResourceArc};

#[derive(NifMap)]
pub struct DeletionVectorNif {
    pub path: String,
    pub storage_type: String,
    pub path_or_inline_dv: String,
    pub offset: Option<i32>,
    pub size_in_bytes: i32,
    pub cardinality: i64,
}

#[rustler::nif]
pub fn deletion_vectors_nif(
    resource: ResourceArc<DeltaTableResource>,
) -> Result<Vec<DeletionVectorNif>, Error> {
    let table = resource.table.read().unwrap();
    let snapshot = table.snapshot().map_err(error::nif("Snapshot"))?;

    let mut out = Vec::new();
    for file in snapshot.log_data().iter() {
        if let Some(dv) = file.deletion_vector_descriptor() {
            out.push(DeletionVectorNif {
                path: file.path().to_string(),
                storage_type: dv.storage_type.to_string(),
                path_or_inline_dv: dv.path_or_inline_dv,
                offset: dv.offset,
                size_in_bytes: dv.size_in_bytes,
                cardinality: dv.cardinality,
            });
        }
    }
    Ok(out)
}
