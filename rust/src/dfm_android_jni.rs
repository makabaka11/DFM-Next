#![allow(non_snake_case)]

#[cfg(target_os = "android")]
use crate::render_engine::engine::attach_present_surface as dfm_attach_present_surface;
#[cfg(target_os = "android")]
use jni_sys::{jboolean, jclass, jint, jlong, jobject, jstring, JNIEnv, JNI_FALSE, JNI_TRUE};
#[cfg(target_os = "android")]
use ndk_sys::ANativeWindow;
#[cfg(target_os = "android")]
use std::ffi::c_void;

#[cfg(target_os = "android")]
#[link(name = "android")]
extern "C" {
    fn ANativeWindow_fromSurface(env: *mut JNIEnv, surface: jobject) -> *mut ANativeWindow;
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_flutter_1rust_1bridge_dfm_1plus_1native_DfmPlusNativePlugin_nativeDfmAttachSurface(
    env: *mut JNIEnv,
    _class: jclass,
    handle: jlong,
    surface: jobject,
    width: jint,
    height: jint,
) -> jboolean {
    if handle == 0 || surface.is_null() || width <= 0 || height <= 0 {
        return JNI_FALSE;
    }

    let native_window = unsafe { ANativeWindow_fromSurface(env, surface) };
    if native_window.is_null() {
        return JNI_FALSE;
    }

    let attached = dfm_attach_present_surface(
        handle as u64,
        native_window as *mut c_void,
        width as u32,
        height as u32,
    );
    if attached {
        JNI_TRUE
    } else {
        JNI_FALSE
    }
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_flutter_1rust_1bridge_dfm_1plus_1native_DfmPlusNativePlugin_nativeDfmEngineCreate(
    _env: *mut JNIEnv,
    _class: jclass,
    width: jint,
    height: jint,
) -> jlong {
    crate::render_engine::ffi::dfm_engine_create(width.max(1) as u32, height.max(1) as u32)
        as jlong
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_flutter_1rust_1bridge_dfm_1plus_1native_DfmPlusNativePlugin_nativeDfmEngineResize(
    _env: *mut JNIEnv,
    _class: jclass,
    handle: jlong,
    width: jint,
    height: jint,
) -> jint {
    crate::render_engine::ffi::dfm_engine_resize(
        handle as u64,
        width.max(1) as u32,
        height.max(1) as u32,
    ) as jint
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_flutter_1rust_1bridge_dfm_1plus_1native_DfmPlusNativePlugin_nativeDfmEngineDispose(
    _env: *mut JNIEnv,
    _class: jclass,
    handle: jlong,
) {
    crate::render_engine::ffi::dfm_engine_dispose(handle as u64);
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_flutter_1rust_1bridge_dfm_1plus_1native_DfmPlusNativePlugin_nativeDfmEngineSetFrame(
    env: *mut JNIEnv,
    _class: jclass,
    handle: jlong,
    frame_json: jstring,
    font_size: f32,
    outline_width: f32,
    shadow_style: jint,
    opacity: f32,
) -> jint {
    if env.is_null() || frame_json.is_null() {
        return 0;
    }
    unsafe {
        let get_string_utf_chars = (**env).v1_1.GetStringUTFChars;
        let release_string_utf_chars = (**env).v1_1.ReleaseStringUTFChars;
        let c_str_ptr = get_string_utf_chars(env, frame_json, std::ptr::null_mut());
        if c_str_ptr.is_null() {
            return 0;
        }
        let ok = crate::render_engine::ffi::dfm_engine_set_frame(
            handle as u64,
            c_str_ptr,
            font_size,
            outline_width,
            shadow_style as u8,
            opacity,
            std::ptr::null(),
            std::ptr::null(),
        ) as jint;
        release_string_utf_chars(env, frame_json, c_str_ptr);
        ok
    }
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_flutter_1rust_1bridge_dfm_1plus_1native_DfmPlusNativePlugin_nativeDfmEngineResetScene(
    _env: *mut JNIEnv,
    _class: jclass,
    handle: jlong,
) -> jint {
    crate::render_engine::ffi::dfm_engine_reset_scene(handle as u64) as jint
}
