import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// --- 数据类型 ---

/// Input danmaku item for layout preparation.
class DfmPlusDanmakuItem {
  final double timeSeconds;
  final String text;
  final int typeCode;
  final int colorArgb;
  final bool isMe;
  final double paintWidth;
  final double paintHeight;

  const DfmPlusDanmakuItem({
    required this.timeSeconds,
    required this.text,
    required this.typeCode,
    required this.colorArgb,
    required this.isMe,
    this.paintWidth = 0.0,
    this.paintHeight = 0.0,
  });
}

class DfmPlusRawDanmakuItem {
  final double timeSeconds;
  final String text;
  final int typeCode;
  final int colorArgb;
  final bool isMe;

  const DfmPlusRawDanmakuItem({
    required this.timeSeconds,
    required this.text,
    required this.typeCode,
    required this.colorArgb,
    required this.isMe,
  });
}

/// Layout preparation request.
class DfmPlusPrepareRequest {
  final List<DfmPlusDanmakuItem> items;
  final double width;
  final double height;
  final double fontSize;
  final double displayArea;
  final double scrollDurationSeconds;
  final bool allowStacking;
  final bool mergeDanmaku;
  final int? maxQuantity;
  final int? maxLinesPerType;
  final double trackGapRatio;
  final double outlineWidth;
  final List<String> blockWords;

  const DfmPlusPrepareRequest({
    required this.items,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.displayArea,
    required this.scrollDurationSeconds,
    required this.allowStacking,
    required this.mergeDanmaku,
    this.maxQuantity,
    this.maxLinesPerType,
    required this.trackGapRatio,
    required this.outlineWidth,
    this.blockWords = const [],
  });
}

class DfmPlusPreparedLayout {
  final BigInt handle;
  final double width;
  final double height;
  final double scrollDurationSeconds;
  final double staticDurationSeconds;
  final List<DfmPlusPreparedItem> items;
  final Float64List itemTimes;
  final int trackCount;

  const DfmPlusPreparedLayout({
    required this.handle,
    required this.width,
    required this.height,
    required this.scrollDurationSeconds,
    required this.staticDurationSeconds,
    required this.items,
    required this.itemTimes,
    required this.trackCount,
  });
}

class DfmPlusPreparedItem {
  final double timeSeconds;
  final String text;
  final int typeCode;
  final int colorArgb;
  final bool isMe;
  final double fontSizeMultiplier;
  final String? countText;
  final int trackIndex;
  final double yPosition;
  final double width;
  final double scrollSpeed;
  final bool isFiltered;
  final double durationSeconds;
  final bool isScroll;
  final double centeredX;

  const DfmPlusPreparedItem({
    required this.timeSeconds,
    required this.text,
    required this.typeCode,
    required this.colorArgb,
    required this.isMe,
    required this.fontSizeMultiplier,
    this.countText,
    required this.trackIndex,
    required this.yPosition,
    required this.width,
    required this.scrollSpeed,
    required this.isFiltered,
    required this.durationSeconds,
    required this.isScroll,
    required this.centeredX,
  });
}

/// Per-frame layout request.
class DfmPlusFrameRequest {
  final BigInt layoutHandle;
  final double currentTimeSeconds;

  const DfmPlusFrameRequest({
    required this.layoutHandle,
    required this.currentTimeSeconds,
  });
}

/// Per-frame layout result.
class DfmPlusFrameLayout {
  final List<DfmPlusFrameItem> items;

  const DfmPlusFrameLayout({required this.items});
}

/// Single frame item with computed position.
class DfmPlusFrameItem {
  final int itemIndex;
  final double x;
  final double y;
  final double offstageX;

  const DfmPlusFrameItem({
    required this.itemIndex,
    required this.x,
    required this.y,
    required this.offstageX,
  });
}

class DfmPlusFontMetrics {
  final double ascent;
  final double descent;
  final double lineHeight;
  final double outlinePx;

  const DfmPlusFontMetrics({
    required this.ascent,
    required this.descent,
    required this.lineHeight,
    required this.outlinePx,
  });
}

// --- API 函数 ---

/// One-time layout preparation using a request object.
Future<DfmPlusPreparedLayout> dfmPlusPrepareLayout({
  required DfmPlusPrepareRequest request,
}) async => _preparedFromJson(_nativeCall('prepare', {
      'items': request.items.map((item) => {
            'time_seconds': item.timeSeconds,
            'text': item.text,
            'type_code': item.typeCode,
            'color_argb': item.colorArgb,
            'is_me': item.isMe,
            'paint_width': item.paintWidth,
            'paint_height': item.paintHeight,
          }).toList(growable: false),
      'width': request.width,
      'height': request.height,
      'font_size': request.fontSize,
      'display_area': request.displayArea,
      'scroll_duration_seconds': request.scrollDurationSeconds,
      'allow_stacking': request.allowStacking,
      'merge_danmaku': request.mergeDanmaku,
      'max_quantity': request.maxQuantity,
      'max_lines_per_type': request.maxLinesPerType,
      'track_gap_ratio': request.trackGapRatio,
      'outline_width': request.outlineWidth,
      'block_words': request.blockWords,
    }) as Map<String, dynamic>);

/// One-time layout preparation with flat parameters (convenience wrapper).
Future<DfmPlusPreparedLayout> dfmPlusPrepareLayoutFull({
  required List<DfmPlusRawDanmakuItem> rawItems,
  required double width,
  required double height,
  required double fontSize,
  required double displayArea,
  required double scrollDurationSeconds,
  required bool allowStacking,
  required bool mergeDanmaku,
  required int? maxQuantity,
  required int? maxLinesPerType,
  required double trackGapRatio,
  required double outlineWidth,
  required Uint8List? customFontBytes,
  required List<String> blockWords,
}) async => _preparedFromJson(_nativeCall('prepare_full', {
      'raw_items': rawItems.map((item) => {
            'time_seconds': item.timeSeconds,
            'text': item.text,
            'type_code': item.typeCode,
            'color_argb': item.colorArgb,
            'is_me': item.isMe,
          }).toList(growable: false),
      'width': width,
      'height': height,
      'font_size': fontSize,
      'display_area': displayArea,
      'scroll_duration_seconds': scrollDurationSeconds,
      'allow_stacking': allowStacking,
      'merge_danmaku': mergeDanmaku,
      'max_quantity': maxQuantity,
      'max_lines_per_type': maxLinesPerType,
      'track_gap_ratio': trackGapRatio,
      'outline_width': outlineWidth,
      'custom_font_bytes': customFontBytes?.toList(),
      'block_words': blockWords,
    }) as Map<String, dynamic>);

/// Per-frame layout query (Rust-side computation).
DfmPlusFrameLayout dfmPlusLayoutFrame({
  required DfmPlusFrameRequest request,
}) {
  final result = _nativeCall('frame', {
    'layout_handle': request.layoutHandle.toInt(),
    'current_time_seconds': request.currentTimeSeconds,
  }) as Map<String, dynamic>;
  return DfmPlusFrameLayout(items: (result['items'] as List).map((raw) {
    final item = raw as Map<String, dynamic>;
    return DfmPlusFrameItem(
      itemIndex: (item['item_index'] as num).toInt(),
      x: (item['x'] as num).toDouble(),
      y: (item['y'] as num).toDouble(),
      offstageX: (item['offstage_x'] as num).toDouble(),
    );
  }).toList(growable: false));
}

void dfmPlusDropLayout({required BigInt handle}) {
  _nativeCall('drop', handle.toInt());
}

/// Measure the rendered width of a single text string.
Future<double> dfmPlusMeasureTextWidth({
  required String text,
  required double fontSize,
  required Uint8List? customFontBytes,
}) async => (_nativeCall('measure_width', {
      'text': text,
      'font_size': fontSize,
      'custom_font_bytes': customFontBytes?.toList(),
    }) as num).toDouble();

/// Measure widths of multiple text strings in a single call.
Future<Float64List> dfmPlusMeasureTextWidths({
  required List<String> texts,
  required double fontSize,
  required Uint8List? customFontBytes,
}) async => Float64List.fromList(
      (_nativeCall('measure_widths', {
        'texts': texts,
        'font_size': fontSize,
        'custom_font_bytes': customFontBytes?.toList(),
      }) as List).map((value) => (value as num).toDouble()).toList(),
    );

Future<DfmPlusFontMetrics> dfmPlusFontMetrics({
  required double fontSize,
  required double outlineWidth,
  required Uint8List? customFontBytes,
}) async {
  final result = _nativeCall('font_metrics', {
    'font_size': fontSize,
    'outline_width': outlineWidth,
    'custom_font_bytes': customFontBytes?.toList(),
  }) as Map<String, dynamic>;
  return DfmPlusFontMetrics(
    ascent: (result['ascent'] as num).toDouble(),
    descent: (result['descent'] as num).toDouble(),
    lineHeight: (result['line_height'] as num).toDouble(),
    outlinePx: (result['outline_px'] as num).toDouble(),
  );
}

DfmPlusPreparedLayout _preparedFromJson(Map<String, dynamic> result) =>
    DfmPlusPreparedLayout(
      handle: BigInt.from(result['handle'] as int),
      width: (result['width'] as num).toDouble(),
      height: (result['height'] as num).toDouble(),
      scrollDurationSeconds:
          (result['scroll_duration_seconds'] as num).toDouble(),
      staticDurationSeconds:
          (result['static_duration_seconds'] as num).toDouble(),
      items: (result['items'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        return DfmPlusPreparedItem(
          timeSeconds: (item['time_seconds'] as num).toDouble(),
          text: item['text'] as String,
          typeCode: (item['type_code'] as num).toInt(),
          colorArgb: (item['color_argb'] as num).toInt(),
          isMe: item['is_me'] as bool,
          fontSizeMultiplier:
              (item['font_size_multiplier'] as num).toDouble(),
          countText: item['count_text'] as String?,
          trackIndex: (item['track_index'] as num).toInt(),
          yPosition: (item['y_position'] as num).toDouble(),
          width: (item['width'] as num).toDouble(),
          scrollSpeed: (item['scroll_speed'] as num).toDouble(),
          isFiltered: item['is_filtered'] as bool,
          durationSeconds: (item['duration_seconds'] as num).toDouble(),
          isScroll: item['is_scroll'] as bool,
          centeredX: (item['centered_x'] as num).toDouble(),
        );
      }).toList(growable: false),
      itemTimes: Float64List.fromList((result['item_times'] as List)
          .map((value) => (value as num).toDouble()).toList()),
      trackCount: (result['track_count'] as num).toInt(),
    );

typedef _CallNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);

final class _NativeApi {
  _NativeApi._(DynamicLibrary library)
      : call = library.lookupFunction<_CallNative, _CallNative>('dfm_layout_api_call'),
        free = library.lookupFunction<_FreeNative, void Function(Pointer<Utf8>)>(
            'dfm_layout_api_free');

  final _CallNative call;
  final void Function(Pointer<Utf8>) free;

  static final _NativeApi instance = _NativeApi._(_openLibrary());

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS) return DynamicLibrary.process();
    final name = Platform.isWindows
        ? 'dfm_plus.dll'
        : Platform.isMacOS
            ? 'libdfm_plus.dylib'
            : 'libdfm_plus.so';
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final paths = <String>[
      name,
      '$executableDir${Platform.pathSeparator}$name',
      if (Platform.isMacOS)
        '$executableDir${Platform.pathSeparator}..${Platform.pathSeparator}Frameworks${Platform.pathSeparator}$name',
    ];
    if (Platform.isMacOS) {
      try {
        final process = DynamicLibrary.process();
        process.lookup<NativeFunction<_CallNative>>('dfm_layout_api_call');
        return process;
      } catch (_) {}
    }
    for (final path in paths) {
      try {
        final library = DynamicLibrary.open(path);
        library.lookup<NativeFunction<_CallNative>>('dfm_layout_api_call');
        return library;
      } catch (_) {}
    }
    throw StateError('DFM+ 原生库 $name 未打包到应用；请先构建并安装 Rust 动态库。');
  }
}

Object? _nativeCall(String operation, Object request) {
  final op = operation.toNativeUtf8(allocator: calloc);
  final input = jsonEncode(request).toNativeUtf8(allocator: calloc);
  try {
    final native = _NativeApi.instance;
    final pointer = native.call(op, input);
    if (pointer == nullptr) throw StateError('DFM+ API returned null');
    try {
      final response = jsonDecode(pointer.toDartString()) as Map<String, dynamic>;
      if (response['error'] case final String error) throw StateError(error);
      return response['result'];
    } finally {
      native.free(pointer);
    }
  } finally {
    calloc.free(op);
    calloc.free(input);
  }
}
