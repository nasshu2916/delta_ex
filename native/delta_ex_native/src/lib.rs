mod arrow;
mod cdf;
mod deletion_vectors;
mod error;
mod expressions;
mod features;
mod filesystem;
mod maintenance;
mod merge;
mod metadata;
mod operations;
mod query;
mod reader;
mod resource;
mod runtime;
mod schema;
mod transactions;
mod writer;

use rustler::{Env, Term};

fn load(env: Env, _info: Term) -> bool {
    let _ = env.register::<resource::DeltaTableResource>();
    // Register cloud object_store handlers so URIs like `s3://...` are routed to
    // the appropriate backend. Without this, deltalake's URL parser does not
    // recognize cloud schemes even when the corresponding feature is enabled.
    deltalake::aws::register_handlers(None);
    true
}

rustler::init!("Elixir.DeltaEx.Native", load = load);
