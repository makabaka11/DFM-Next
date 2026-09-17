pub(crate) mod engine;
pub mod ffi;
mod present;

/// Signed MSDF range wide enough for the thick outline profile.
pub(crate) const DANMAKU_MSDF_RANGE: f64 = 10.0;

/// Shared font bytes used by both the GPU atlas and DFM+ collision metrics.
pub(crate) static DEFAULT_FONT_DATA: &[u8] = include_bytes!("../../assets/subfont.ttf");
pub(crate) static FALLBACK_FONT_DATA: &[&[u8]] = &[
    include_bytes!("../../assets/dfm_fonts/NotoSansYi-Regular.ttf"),
    include_bytes!("../../assets/dfm_fonts/NotoSansGeorgian-Regular.ttf"),
    include_bytes!("../../assets/dfm_fonts/NotoSansLao-Regular.ttf"),
];

/// Resolve the three user-facing outline levels to a safe MSDF width.
pub(crate) fn resolve_danmaku_outline_px(font_size: f32, width_level: f32) -> f32 {
    if !width_level.is_finite() || width_level <= 0.0 {
        return 0.0;
    }
    let thin_px = (font_size * 0.06).clamp(1.0, 2.6);
    if width_level < 1.5 {
        thin_px
    } else {
        (thin_px * 1.5).min(DANMAKU_MSDF_RANGE as f32 * 0.5 - 1.0)
    }
}
