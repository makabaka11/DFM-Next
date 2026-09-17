# DFM+ native GPU demo

`demo` is a five-minute pseudo player for the standalone DFM+ engine. The
background is a fake video scene; the danmaku uses the real Rust layout API and
the `dfm_engine_*` native GPU texture pipeline. It does not include a Web target.

The demo creates deterministic danmaku across 00:00–05:00, including right-to-left,
left-to-right, top-fixed, and bottom-fixed modes. You can seek, pause, change
playback rate, send your own danmaku, hide the overlay, and adjust font size,
opacity, display area, scroll duration, time offset, track gap, stacking,
duplicate merge, outline, shadow, supersampling, quantity/track limits, and
blocked words.

From this folder, use a **release** build for the target platform:

```bash
flutter pub get
flutter build macos --release
flutter build ios --release --no-codesign
flutter build apk --release
flutter build windows --release
flutter build linux --release
```

Run `dart analyze lib test` for a static source check. The Rust toolchain and
the target platform's Flutter build tools are required. The `dfm_plus_native`
plugin calls Cargokit to build and package the sibling `../rust` crate during
each native build. Web is deliberately excluded because no Rust WASM renderer
or Flutter texture implementation is provided.

The player source is in `lib/main.dart`, the sample data in
`lib/demo_danmaku.dart`, and the platform texture plugin in
`../native_plugin`.
