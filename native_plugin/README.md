# DFM+ native texture plugin

This local Flutter plugin registers the `dfm_plus/texture` channel and builds
the sibling `../rust` crate with Cargokit. It presents frames from the Rust
`dfm_engine_*` GPU renderer as a Flutter texture on Android, iOS, macOS,
Windows, and Linux. The Dart widget and layout FFI live in `../flutter`; the
five-minute release demo lives in `../demo`.
