import 'dart:ui';

enum DanmakuItemType { scroll, top, bottom }

enum DanmakuShadowStyle { none, soft, medium, strong }

class DanmakuContentItem {
  /// 弹幕文本
  final String text;

  /// 弹幕颜色
  final Color color;

  /// 弹幕类型
  final DanmakuItemType type;

  /// 时间偏移（毫秒），用于时间轴跳转后的运动中途弹幕
  final int timeOffset;

  /// 轨道编号，用于状态恢复时强制使用相同轨道
  final int? trackIndex;

  /// 字体大小倍率（用于合并弹幕）
  final double fontSizeMultiplier;

  /// 合并弹幕的计数文本（如 x15），为 null 表示不是合并弹幕
  final String? countText;

  /// 滚动弹幕的初始X坐标
  final double? scrollOriginalX;

  /// 是否是用户自己发送的弹幕
  final bool isMe;

  DanmakuContentItem(
    this.text, {
    this.color = const Color(0xFFFFFFFF),
    this.type = DanmakuItemType.scroll,
    this.timeOffset = 0,
    this.trackIndex,
    this.fontSizeMultiplier = 1.0,
    this.countText,
    this.scrollOriginalX,
    this.isMe = false,
  });
}

/// Mutable layout result for a danmaku item.
///
/// x/y/offstageX are intentionally mutable so layout results can be reused
/// across frames without creating new objects every tick.
class PositionedDanmakuItem {
  final DanmakuContentItem content;
  double x;
  double y;
  double offstageX;
  final double time;

  /// 滚动弹幕的水平移动速度（像素/秒）。
  /// Painter 利用此值做增量定位，避免绝对位置计算在倍速下因帧间隔
  /// 抖动而产生视觉跳跃。非滚动弹幕此值为 0。
  double scrollSpeed;

  /// 弹幕文本宽度（像素）。Painter 利用此值做视口剔除，
  /// 跳过完全不可见的弹幕，避免无谓的 Paragraph 查找与绘制。
  double width;

  /// Painter 增量定位使用的显示 X 坐标。
  /// 初始值为 NaN，Painter 首次渲染时从 [x] 初始化；
  /// 之后每帧按 `displayX -= scrollSpeed * dt` 递减，
  /// 消除绝对位置 `x = width - speed * elapsed` 在高倍速下的帧间隔抖动。
  double displayX = double.nan;

  PositionedDanmakuItem({
    required this.content,
    required this.x,
    required this.y,
    required this.offstageX,
    required this.time,
    this.scrollSpeed = 0.0,
    this.width = 0.0,
  });
}
