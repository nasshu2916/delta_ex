use crate::error;
use arrow::array::{
    Array, BooleanArray, BooleanBuilder, Float64Array, Float64Builder, Int64Array, Int64Builder,
    StringArray, StringBuilder,
};
use arrow::datatypes::{DataType, Field, Schema};
use arrow::record_batch::RecordBatch;
use deltalake::kernel::{DataType as DeltaDataType, PrimitiveType};
use rustler::{Encoder, Env, Error, Term};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;

pub fn parse_delta_data_type(name: &str) -> Result<DeltaDataType, String> {
    match name.to_lowercase().as_str() {
        "string" | "utf8" => Ok(DeltaDataType::Primitive(PrimitiveType::String)),
        "integer" | "int64" => Ok(DeltaDataType::Primitive(PrimitiveType::Long)),
        "float" | "float64" => Ok(DeltaDataType::Primitive(PrimitiveType::Double)),
        "boolean" | "bool" => Ok(DeltaDataType::Primitive(PrimitiveType::Boolean)),
        other => Err(format!("Unsupported data type: {}", other)),
    }
}

pub fn terms_to_record_batch(data: Term) -> Result<RecordBatch, Error> {
    let list: Vec<HashMap<String, Term>> = data.decode()?;
    if list.is_empty() {
        return Err(error::nif_msg("Empty data"));
    }

    // Collect all unique keys from all rows
    let mut all_keys = HashSet::new();
    for row in &list {
        for key in row.keys() {
            all_keys.insert(key.clone());
        }
    }
    let mut keys: Vec<String> = all_keys.into_iter().collect();
    keys.sort();

    let mut fields = Vec::new();
    for name in &keys {
        // Find first non-nil value to determine type
        let mut dtype = DataType::Utf8; // Default
        for row in &list {
            if let Some(value) = row.get(name) {
                let is_nil = value.is_atom() && {
                    let s = format!("{:?}", value);
                    s == "nil"
                };

                if !is_nil {
                    if value.decode::<i64>().is_ok() {
                        dtype = DataType::Int64;
                    } else if value.decode::<f64>().is_ok() {
                        dtype = DataType::Float64;
                    } else if value.decode::<bool>().is_ok() {
                        dtype = DataType::Boolean;
                    } else if value.decode::<String>().is_ok() {
                        dtype = DataType::Utf8;
                    }
                    break;
                }
            }
        }
        fields.push(Field::new(name, dtype, true));
    }
    let schema = Arc::new(Schema::new(fields));

    let mut columns: Vec<Arc<dyn Array>> = Vec::new();
    for field in schema.fields() {
        let name = field.name();
        match field.data_type() {
            DataType::Int64 => {
                let mut builder = Int64Builder::new();
                for row in &list {
                    builder.append_option(row.get(name).and_then(|t| t.decode::<i64>().ok()));
                }
                columns.push(Arc::new(builder.finish()));
            }
            DataType::Float64 => {
                let mut builder = Float64Builder::new();
                for row in &list {
                    builder.append_option(row.get(name).and_then(|t| t.decode::<f64>().ok()));
                }
                columns.push(Arc::new(builder.finish()));
            }
            DataType::Boolean => {
                let mut builder = BooleanBuilder::new();
                for row in &list {
                    builder.append_option(row.get(name).and_then(|t| t.decode::<bool>().ok()));
                }
                columns.push(Arc::new(builder.finish()));
            }
            DataType::Utf8 => {
                let mut builder = StringBuilder::new();
                for row in &list {
                    builder.append_option(row.get(name).and_then(|t| t.decode::<String>().ok()));
                }
                columns.push(Arc::new(builder.finish()));
            }
            _ => unreachable!(),
        }
    }

    RecordBatch::try_new(schema, columns).map_err(error::nif("RecordBatch"))
}

pub fn record_batches_to_list<'a>(env: Env<'a>, batches: Vec<RecordBatch>) -> Term<'a> {
    let mut list = Vec::new();

    for batch in batches {
        let num_rows = batch.num_rows();
        let schema = batch.schema();
        let columns = batch.columns();

        for row_idx in 0..num_rows {
            let mut map = HashMap::new();
            for (col_idx, field) in schema.fields().iter().enumerate() {
                let name = field.name();
                let array = &columns[col_idx];
                let value = array_to_term(env, array.as_ref(), row_idx);
                map.insert(name.clone(), value);
            }
            list.push(map);
        }
    }

    list.encode(env)
}

fn array_to_term<'a>(env: Env<'a>, array: &dyn Array, index: usize) -> Term<'a> {
    if array.is_null(index) {
        return rustler::types::atom::nil().encode(env);
    }

    match array.data_type() {
        DataType::Boolean => {
            let array = array.as_any().downcast_ref::<BooleanArray>().unwrap();
            array.value(index).encode(env)
        }
        DataType::Int64 => {
            let array = array.as_any().downcast_ref::<Int64Array>().unwrap();
            array.value(index).encode(env)
        }
        DataType::Float64 => {
            let array = array.as_any().downcast_ref::<Float64Array>().unwrap();
            array.value(index).encode(env)
        }
        DataType::Utf8 => {
            let array = array.as_any().downcast_ref::<StringArray>().unwrap();
            array.value(index).encode(env)
        }
        _ => "Unsupported Type".encode(env),
    }
}
