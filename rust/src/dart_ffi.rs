use std::ffi::{c_char, CStr, CString};
use serde::Deserialize;
use serde_json::{json, Value};
use crate::api::dfm_plus as api;

#[derive(Deserialize)]
struct MeasureWidths {
    texts: Vec<String>,
    font_size: f64,
    custom_font_bytes: Option<Vec<u8>>,
}

#[derive(Deserialize)]
struct MeasureWidth {
    text: String,
    font_size: f64,
    custom_font_bytes: Option<Vec<u8>>,
}

#[derive(Deserialize)]
struct FontMetrics {
    font_size: f64,
    outline_width: f64,
    custom_font_bytes: Option<Vec<u8>>,
}

#[derive(Deserialize)]
struct PrepareFull {
    raw_items: Vec<api::DfmPlusRawDanmakuItem>,
    width: f64,
    height: f64,
    font_size: f64,
    display_area: f64,
    scroll_duration_seconds: f64,
    allow_stacking: bool,
    merge_danmaku: bool,
    max_quantity: Option<u32>,
    max_lines_per_type: Option<u32>,
    track_gap_ratio: f64,
    outline_width: f64,
    custom_font_bytes: Option<Vec<u8>>,
    block_words: Vec<String>,
}

fn dispatch(op: &str, input: &str) -> Result<Value, String> {
    match op {
        "prepare" => {
            let request = serde_json::from_str(input).map_err(|e| e.to_string())?;
            let result = api::dfm_plus_prepare_layout(request)?;
            serde_json::to_value(result).map_err(|e| e.to_string())
        }
        "prepare_full" => {
            let p: PrepareFull = serde_json::from_str(input).map_err(|e| e.to_string())?;
            let result = api::dfm_plus_prepare_layout_full(
                p.raw_items, p.width, p.height, p.font_size, p.display_area,
                p.scroll_duration_seconds, p.allow_stacking, p.merge_danmaku,
                p.max_quantity, p.max_lines_per_type, p.track_gap_ratio,
                p.outline_width, p.custom_font_bytes, p.block_words,
            )?;
            serde_json::to_value(result).map_err(|e| e.to_string())
        }
        "measure_widths" => {
            let p: MeasureWidths = serde_json::from_str(input).map_err(|e| e.to_string())?;
            let widths = api::dfm_plus_measure_text_widths(
                p.texts, p.font_size, p.custom_font_bytes)?;
            Ok(json!(widths))
        }
        "measure_width" => {
            let p: MeasureWidth = serde_json::from_str(input).map_err(|e| e.to_string())?;
            let width = api::dfm_plus_measure_text_width(
                p.text, p.font_size, p.custom_font_bytes)?;
            Ok(json!(width))
        }
        "font_metrics" => {
            let p: FontMetrics = serde_json::from_str(input).map_err(|e| e.to_string())?;
            let metrics = api::dfm_plus_font_metrics(
                p.font_size, p.outline_width, p.custom_font_bytes)?;
            serde_json::to_value(metrics).map_err(|e| e.to_string())
        }
        "frame" => {
            let request = serde_json::from_str(input).map_err(|e| e.to_string())?;
            serde_json::to_value(api::dfm_plus_layout_frame(request))
                .map_err(|e| e.to_string())
        }
        "drop" => {
            let handle: u64 = serde_json::from_str(input).map_err(|e| e.to_string())?;
            api::dfm_plus_drop_layout(handle);
            Ok(Value::Null)
        }
        _ => Err(format!("unknown DFM+ API operation: {op}")),
    }
}

/// One JSON call boundary for Dart FFI. Returned strings belong to Rust and
/// must be released with dfm_layout_api_free.
#[no_mangle]
pub extern "C" fn dfm_layout_api_call(op: *const c_char, input: *const c_char) -> *mut c_char {
    let response = std::panic::catch_unwind(|| {
        if op.is_null() || input.is_null() {
            return json!({"error": "null DFM+ API argument"});
        }
        let op = unsafe { CStr::from_ptr(op) }.to_str();
        let input = unsafe { CStr::from_ptr(input) }.to_str();
        match (op, input) {
            (Ok(op), Ok(input)) => match dispatch(op, input) {
                Ok(result) => json!({"result": result}),
                Err(error) => json!({"error": error}),
            },
            _ => json!({"error": "DFM+ API arguments are not UTF-8"}),
        }
    }).unwrap_or_else(|_| json!({"error": "DFM+ API panicked"}));
    CString::new(response.to_string()).expect("JSON has no NUL").into_raw()
}

#[no_mangle]
pub extern "C" fn dfm_layout_api_free(value: *mut c_char) {
    if !value.is_null() {
        unsafe { drop(CString::from_raw(value)); }
    }
}

#[cfg(test)]
mod tests {
    use super::dispatch;

    #[test]
    fn json_boundary_prepares_and_drops_real_layout() {
        let input = r#"{"items":[{"time_seconds":0.1,"text":"测试","type_code":1,"color_argb":-1,"is_me":false,"paint_width":50.0,"paint_height":25.0}],"width":1280.0,"height":720.0,"font_size":25.0,"display_area":1.0,"scroll_duration_seconds":8.0,"allow_stacking":false,"merge_danmaku":false,"max_quantity":null,"max_lines_per_type":null,"track_gap_ratio":0.15,"outline_width":1.0,"block_words":[]}"#;
        let result = dispatch("prepare", input).expect("prepare");
        let handle = result["handle"].as_u64().expect("handle");
        assert_eq!(result["items"].as_array().unwrap().len(), 1);
        dispatch("drop", &handle.to_string()).expect("drop");
    }
}
