/// Shared font bytes used by both the GPU atlas and DFM+ collision metrics.
pub(crate) static DEFAULT_FONT_DATA: &[u8] = include_bytes!("../../assets/subfont.ttf");
pub(crate) static FALLBACK_FONT_DATA: &[&[u8]] = &[
    include_bytes!("../../assets/dfm_fonts/NotoSansYi-Regular.ttf"),
    include_bytes!("../../assets/dfm_fonts/NotoSansGeorgian-Regular.ttf"),
    include_bytes!("../../assets/dfm_fonts/NotoSansLao-Regular.ttf"),
];

include!("engine/runtime.rs");
include!("engine/rendering.rs");
include!("engine/renderer_core.rs");
include!("engine/renderer_draw.rs");
include!("engine/frame.rs");
include!("engine/shaders.rs");

pub mod present;
pub mod ffi;
