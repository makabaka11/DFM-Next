import 'dart:ui';

enum DanmakuItemType { scroll, top, bottom }

enum DanmakuShadowStyle { none, soft, medium, strong }

class DanmakuContentItem {
  final String text;
  final DanmakuItemType type;
  final Color color;
  final bool isMe;
  final double fontSizeMultiplier;
  final String? countText;

  const DanmakuContentItem(
    this.text, {
    this.type = DanmakuItemType.scroll,
    this.color = const Color(0xFFFFFFFF),
    this.isMe = false,
    this.fontSizeMultiplier = 1.0,
    this.countText,
  });
}

class PositionedDanmakuItem {
  final DanmakuContentItem content;
  final double x;
  final double y;
  final double offstageX;
  final double time;

  const PositionedDanmakuItem({
    required this.content,
    required this.x,
    required this.y,
    required this.offstageX,
    required this.time,
  });
}
