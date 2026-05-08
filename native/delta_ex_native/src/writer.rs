use crate::error;
use crate::filesystem::{parse_uri, table_builder};
use crate::runtime::RUNTIME;
use crate::schema::terms_to_record_batch;
use deltalake::kernel::transaction::CommitProperties;
use deltalake::kernel::Transaction;
use deltalake::protocol::SaveMode;
use rustler::{Error, NifMap, Term};
use std::collections::HashMap;
use std::num::NonZeroU64;

#[derive(NifMap, Default)]
pub struct WriteOpts {
    pub app_metadata: Option<HashMap<String, String>>,
    pub target_file_size: Option<u64>,
    pub write_batch_size: Option<u64>,
    pub app_transaction_app_id: Option<String>,
    pub app_transaction_version: Option<i64>,
    pub storage_options: Option<HashMap<String, String>>,
}

#[rustler::nif]
pub fn insert_nif(uri: String, data: Term) -> Result<(), Error> {
    do_insert(uri, data, WriteOpts::default())
}

#[rustler::nif]
pub fn insert_with_opts_nif(uri: String, data: Term, opts: WriteOpts) -> Result<(), Error> {
    do_insert(uri, data, opts)
}

fn do_insert(uri: String, data: Term, mut opts: WriteOpts) -> Result<(), Error> {
    let batch = terms_to_record_batch(data)?;
    let storage_options = opts.storage_options.take();

    RUNTIME
        .block_on(async {
            // Local filesystem URIs need the directory to exist; cloud schemes
            // (s3, gs, az, ...) are handled by their object_store implementation.
            if let Ok(url) = parse_uri(&uri) {
                if url.scheme() == "file" {
                    if let Ok(path) = url.to_file_path() {
                        let _ = std::fs::create_dir_all(&path);
                    }
                }
            }

            let mut table = table_builder(&uri, storage_options)?.build()?;
            match table.load().await {
                Ok(_) => {}
                Err(deltalake::DeltaTableError::NotATable(_)) => {}
                Err(e) => return Err(e),
            }

            let mut writer = table.write(vec![batch]).with_save_mode(SaveMode::Append);

            if let Some(target_file_size) = opts.target_file_size {
                writer = writer.with_target_file_size(NonZeroU64::new(target_file_size));
            }

            if let Some(batch_size) = opts.write_batch_size {
                writer = writer.with_write_batch_size(batch_size as usize);
            }

            let mut commit_properties = CommitProperties::default();
            let mut has_commit_props = false;

            if let Some(metadata) = opts.app_metadata {
                let entries: Vec<(String, serde_json::Value)> = metadata
                    .into_iter()
                    .map(|(k, v)| (k, serde_json::Value::String(v)))
                    .collect();
                commit_properties = commit_properties.with_metadata(entries);
                has_commit_props = true;
            }

            if let (Some(app_id), Some(version)) =
                (opts.app_transaction_app_id, opts.app_transaction_version)
            {
                commit_properties = commit_properties
                    .with_application_transaction(Transaction::new(&app_id, version));
                has_commit_props = true;
            }

            if has_commit_props {
                writer = writer.with_commit_properties(commit_properties);
            }

            writer.await?;
            Ok::<(), deltalake::DeltaTableError>(())
        })
        .map_err(error::nif("Insert"))?;

    Ok(())
}
