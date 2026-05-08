use deltalake::DeltaTable;
use rustler::Resource;
use std::sync::RwLock;

pub struct DeltaTableResource {
    pub table: RwLock<DeltaTable>,
}

impl Resource for DeltaTableResource {}
