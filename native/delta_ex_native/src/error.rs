//! NIF から Elixir 側へ返すエラー文字列のフォーマットを統一するヘルパー群。
//!
//! 形式は `"<context>: <cause>"`（例: `"Snapshot: invalid log entry"`）に揃える。
//! `context` は操作・サブ処理を表す静的文字列で、call site で簡潔に与える。

use rustler::Error;
use std::fmt::Display;

/// `<context>: <cause>` 形式の `rustler::Error::Term` を直接組み立てる。
pub fn nif_error<E: Display>(context: &'static str, e: E) -> Error {
    Error::Term(Box::new(format!("{}: {}", context, e)))
}

/// `.map_err(error::nif("Snapshot"))` の形で使う `rustler::Error` 用クロージャ。
#[inline]
pub fn nif<E: Display>(context: &'static str) -> impl FnOnce(E) -> Error {
    move |e| nif_error(context, e)
}

/// 原因（cause）のない平文メッセージを `rustler::Error::Term` にする。
pub fn nif_msg<S: Into<String>>(msg: S) -> Error {
    Error::Term(Box::new(msg.into()))
}

/// `.map_err(error::delta("Predicate"))` の形で使う `DeltaTableError::Generic` 用クロージャ。
/// async ブロック内で `DeltaTableError` に揃えて伝播させたいときに使う。
#[inline]
pub fn delta<E: Display>(context: &'static str) -> impl FnOnce(E) -> deltalake::DeltaTableError {
    move |e| deltalake::DeltaTableError::Generic(format!("{}: {}", context, e))
}
