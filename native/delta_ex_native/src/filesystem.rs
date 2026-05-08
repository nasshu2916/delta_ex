use deltalake::{DeltaTableBuilder, DeltaTableError};
use std::collections::HashMap;
use url::Url;

/// Build a `DeltaTableBuilder` from a URI plus optional object_store options.
///
/// `storage_options` is a free-form key/value map forwarded to the underlying
/// object_store implementation (e.g. AWS credentials, endpoint URL, region).
pub fn table_builder(
    uri: &str,
    storage_options: Option<HashMap<String, String>>,
) -> Result<DeltaTableBuilder, DeltaTableError> {
    let url = parse_uri(uri).map_err(DeltaTableError::Generic)?;
    let mut builder = DeltaTableBuilder::from_url(url)?;
    if let Some(opts) = storage_options {
        if !opts.is_empty() {
            builder = builder.with_storage_options(opts);
        }
    }
    Ok(builder)
}

pub fn parse_uri(uri: &str) -> Result<Url, String> {
    match Url::parse(uri) {
        Ok(url) => Ok(url),
        Err(url::ParseError::RelativeUrlWithoutBase) => {
            let path = std::path::Path::new(uri);
            let abs_path = if path.is_absolute() {
                path.to_path_buf()
            } else {
                std::env::current_dir()
                    .map_err(|e| format!("Current Dir: {}", e))?
                    .join(path)
            };
            // Canonicalize to resolve symlinks like /var -> /private/var on macOS
            let canonical_path = std::fs::canonicalize(&abs_path).unwrap_or(abs_path);
            Url::from_file_path(canonical_path).map_err(|_| "Invalid local path".to_string())
        }
        Err(e) => Err(format!("URL Parse: {}", e)),
    }
}
