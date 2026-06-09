// TODO: 此文件应由 flutter_rust_bridge 自动生成
// 运行: flutter_rust_bridge_codegen generate
//
// 原始集成版导入: package:nipaplay/src/rust/api/dfm_plus.dart
//
// 此占位文件定义了 DfmPlusLayoutBridge 所需的类型和函数签名，
// 实际使用时请替换为 flutter_rust_bridge 生成的绑定代码

import 'dart:typed_data';

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
}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}

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
}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}

/// Per-frame layout query (Rust-side computation).
DfmPlusFrameLayout dfmPlusLayoutFrame({
  required DfmPlusFrameRequest request,
}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}

void dfmPlusDropLayout({required BigInt handle}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}

/// Measure the rendered width of a single text string.
Future<double> dfmPlusMeasureTextWidth({
  required String text,
  required double fontSize,
  required Uint8List? customFontBytes,
}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}

/// Measure widths of multiple text strings in a single call.
Future<Float64List> dfmPlusMeasureTextWidths({
  required List<String> texts,
  required double fontSize,
  required Uint8List? customFontBytes,
}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}

Future<DfmPlusFontMetrics> dfmPlusFontMetrics({
  required double fontSize,
  required double outlineWidth,
  required Uint8List? customFontBytes,
}) {
  throw UnimplementedError(
    '请运行 flutter_rust_bridge_codegen generate 生成绑定',
  );
}
