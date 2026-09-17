/// Deterministic five-minute sample. Times are seconds, as expected by DFM+.
List<Map<String, dynamic>> buildDemoDanmaku() {
  const phrases = <String>[
    '开场！弹幕引擎开始工作', '这段运动很流畅', '试试暂停和拖动时间轴',
    '233333', '右向左滚动弹幕', '彩色弹幕来了', '轨道碰撞避让测试',
    '提高播放速度看看', 'DFM+ 独立版演示', '发送一条自己的弹幕吧',
    '这条会和相同内容合并', '顶部固定弹幕', '底部固定弹幕',
    '左向右滚动弹幕', '看看描边和阴影设置', '五分钟时间轴仍在继续',
  ];
  const colors = <int>[
    0xFFFFFFFF, 0xFFFFE082, 0xFF80DEEA, 0xFFA5D6A7,
    0xFFF48FB1, 0xFFB39DDB, 0xFFFFAB91,
  ];
  final result = <Map<String, dynamic>>[];
  for (var second = 0; second < 300; second++) {
    final count = second % 13 == 0 ? 4 : second % 3 == 0 ? 2 : 1;
    for (var index = 0; index < count; index++) {
      final serial = second * 4 + index;
      final type = serial % 37 == 0
          ? 5
          : serial % 41 == 0
              ? 4
              : serial % 53 == 0
                  ? 6
                  : 1;
      result.add(<String, dynamic>{
        'time': second + 0.15 + index * 0.21,
        'content': phrases[serial % phrases.length],
        'type': type,
        'color': colors[serial % colors.length],
        'isMe': false,
      });
    }
  }
  result.sort((a, b) => (a['time'] as num).compareTo(b['time'] as num));
  return result;
}
