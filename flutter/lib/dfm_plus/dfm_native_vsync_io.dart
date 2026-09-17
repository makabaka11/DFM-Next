import 'dart:ffi';
import 'dart:io';

typedef _NativeVsync = Uint8 Function(Uint64, Uint64);
typedef _Vsync = int Function(int, int);

class DfmNativeVsync {
  static final _Vsync? _signal = _load();

  static _Vsync? _load() {
    if (!Platform.isWindows) return null;
    try {
      final directory = File(Platform.resolvedExecutable).parent.path;
      final library = DynamicLibrary.open(
        '$directory${Platform.pathSeparator}dfm_plus.dll',
      );
      return library.lookupFunction<_NativeVsync, _Vsync>('dfm_engine_vsync');
    } catch (_) {
      return null;
    }
  }

  static bool signal(int handle, int elapsedUs) =>
      _signal?.call(handle, elapsedUs) == 1;
}
