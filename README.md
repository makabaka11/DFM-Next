# DFM+ (DFM-Next)

> **预计算布局 + Rust 计算层 + GPU 渲染层 + Flutter Widget** 的弹幕引擎，从 B 站开源 [DanmakuFlameMaster](https://github.com/Bilibili/DanmakuFlameMaster) 算法 1:1 移植。

---

## Quick Start

### 1. 添加依赖

```yaml
# pubspec.yaml
dependencies:
  dfm_plus:
    path: /path/to/DFM+/flutter
```

Rust 渲染引擎需要以 cdylib 方式编译并放入 Flutter 的 native assets 目录。最简单的方式是通过 `flutter_rust_bridge` 或手动 `cargo build` 后将动态库放入对应平台目录。

### 2. 最小可运行示例

以下是一个完整的 `main.dart`，可直接运行并看到滚动弹幕：

```dart
import 'package:flutter/material.dart';
import 'package:dfm_plus/dfm_plus_overlay.dart';
import 'package:dfm_plus/danmaku_types.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DanmakuDemoPage(),
    );
  }
}

class DanmakuDemoPage extends StatefulWidget {
  const DanmakuDemoPage({super.key});

  @override
  State<DanmakuDemoPage> createState() => _DanmakuDemoPageState();
}

class _DanmakuDemoPageState extends State<DanmakuDemoPage> {
  /// 播放时间锚点（毫秒），由 ValueNotifier 驱动
  final ValueNotifier<double> _playbackTimeMs = ValueNotifier(0.0);

  /// 弹幕列表
  final List<Map<String, dynamic>> _danmakuList = [];

  /// 弹幕列表版本号，每次变更递增
  int _danmakuListVersion = 0;

  bool _isPlaying = true;
  double _playbackRate = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSampleDanmaku();
    _startPlayback();
  }

  @override
  void dispose() {
    _playbackTimeMs.dispose();
    super.dispose();
  }

  void _loadSampleDanmaku() {
    // 生成示例弹幕：不同时间、类型、颜色
    final samples = [
      {'time': 1.0, 'text': '前方高能！', 'type': 1, 'color': 0xFFFFFFFF},
      {'time': 2.0, 'text': '233333', 'type': 1, 'color': 0xFFFFFF00},
      {'time': 3.0, 'text': '太强了', 'type': 1, 'color': 0xFF00FF00},
      {'time': 4.0, 'text': '顶部公告', 'type': 5, 'color': 0xFFFF0000},
      {'time': 5.0, 'text': '底部弹幕', 'type': 4, 'color': 0xFF00FFFF},
      {'time': 5.5, 'text': '哈哈哈哈哈', 'type': 1, 'color': 0xFFFFFFFF},
      {'time': 6.0, 'text': '好耶！', 'type': 1, 'color': 0xFFFF69B4},
      {'time': 7.0, 'text': '来了来了', 'type': 1, 'color': 0xFFFFFFFF},
      {'time': 8.0, 'text': '这波操作秀', 'type': 1, 'color': 0xFFFFA500},
      {'time': 9.0, 'text': '冲冲冲', 'type': 1, 'color': 0xFF00FF7F},
      {'time': 10.0, 'text': '弹幕测试', 'type': 6, 'color': 0xFFFFFFFF},
      {'time': 11.0, 'text': '左→右滚动', 'type': 6, 'color': 0xFF87CEEB},
      {'time': 12.0, 'text': '精彩！', 'type': 5, 'color': 0xFFFFD700},
      {'time': 13.0, 'text': '太棒了吧', 'type': 1, 'color': 0xFFFFFFFF},
      {'time': 14.0, 'text': '下次还来', 'type': 1, 'color': 0xFFDDA0DD},
      {'time': 15.0, 'text': '完结撒花', 'type': 4, 'color': 0xFFFF4500},
    ];

    for (final s in samples) {
      _danmakuList.add({
        'time': s['time'],
        'text': s['text'],
        'type': s['type'],
        'color': s['color'],
      });
    }
    _danmakuListVersion++;
  }

  void _startPlayback() {
    // 简单的播放时间推进：每 16ms 更新一次
    Future.delayed(const Duration(milliseconds: 16), () {
      if (!mounted) return;
      if (_isPlaying) {
        _playbackTimeMs.value += 16.0 * _playbackRate;
      }
      _startPlayback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 弹幕覆盖层
          Positioned.fill(
            child: DfmPlusOverlay(
              danmakuList: _danmakuList,
              danmakuListVersion: _danmakuListVersion,
              playbackTimeMs: _playbackTimeMs,
              currentTimeSeconds: _playbackTimeMs.value / 1000.0,
              fontSize: 25.0,
              isVisible: true,
              opacity: 1.0,
              displayArea: 0.75,
              timeOffset: 0.0,
              scrollDurationSeconds: 8.0,
              allowStacking: false,
              mergeDanmaku: false,
              customFontFamily: '',
              customFontFilePath: '',
              outlineWidth: 1.5,
              shadowStyle: DanmakuShadowStyle.medium,
              trackGapRatio: 0.15,
              isPlaying: _isPlaying,
              playbackRate: _playbackRate,
              supersampleMultiplier: 2.0,
            ),
          ),

          // 控制栏
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                const Text('速度:', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  value: _playbackRate,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                    DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _playbackRate = v);
                  },
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _danmakuList.add({
                        'time': _playbackTimeMs.value / 1000.0,
                        'text': '实时弹幕 ${_danmakuList.length + 1}',
                        'type': 1,
                        'color': 0xFFFFFFFF,
                      });
                      _danmakuListVersion++;
                    });
                  },
                  child: const Text('发送弹幕', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

运行后即可看到弹幕从右向左滚动，支持暂停/播放、倍速切换、实时发送弹幕。

---

## 架构

```
┌───────────────────────────────────────────────────────────┐
│  Flutter Widget 层                                        │
│  DfmPlusOverlay ── DfmTextureBridge (GPU 纹理)            │
│       │               DfmEmojiPipeline (Emoji 栅格化)      │
│       │ layout() → List<PositionedDanmakuItem>            │
│  DfmPlusLayoutBridge (增量配置 + 同步帧计算)               │
├───────────────────────────────────────────────────────────┤
│  Rust 布局层 (dfm_core + api)                             │
│  dfm_plus_prepare_layout() ← 一次性预计算                  │
│    ├─ FilterSystem → 5 种过滤器                            │
│    ├─ DanmakuRetainer → 轨道碰撞避让 + proximity-evict     │
│    └─ → DfmPlusPreparedLayout (句柄存储)                   │
│  dfm_plus_layout_frame() ← 每帧 O(log N) 查询             │
├───────────────────────────────────────────────────────────┤
│  Rust 渲染层 (render_engine)                              │
│  DfmRenderer (wgpu) → MTSDF 字形 + GPU 并行渲染           │
│    ├─ 非阻塞 MSDF 栅格化 (4ms 预算)                        │
│    ├─ 提交间隔 EMA 自适应插值门控                           │
│    └─ Metal / DX12 / OpenGL / Android Surface             │
└───────────────────────────────────────────────────────────┘
```

**核心思想：** 全部布局计算前移到 `prepare_layout` 阶段一次性完成，每帧仅需 O(log N) 二分查找 + 线性 X 坐标计算。帧查询零 String 分配，布局数据通过不透明句柄存储在 Rust 侧，避免每帧 MB 级序列化。

---

## 支持的弹幕类型

| 类型 | 代码 | 位置计算 | 持续时间 |
|------|------|----------|----------|
| ScrollRL | 1 | `x = width - speed × elapsed` | 可配置 |
| ScrollLR | 6 | `x = speed × elapsed - paint_width` | 可配置 |
| FixTop | 5 | 水平居中 | 3.8s |
| FixBottom | 4 | 水平居中 | 3.8s |
| Special | 7 | 多段线性插值 + alpha 渐变 | 可配置 |

---

## 核心算法

### 轨道分配 (Retainer)

画面垂直方向划分为等高轨道，每种类型独立维护轨道数组：

- **滚动弹幕：** 空轨道直接放置 → 碰撞检测 → 全碰撞时 proximity-evict（保护顶部 40%，底部 60% 中替换最接近退出的单条弹幕）→ `is_me` 强制第 0 轨道
- **固定弹幕：** 时间不重叠追加到同轨道 → 全占用则丢弃

### 过滤系统

两级管线，布局前执行一次：

1. **主过滤：** 类型屏蔽 → 数量密度 → 帧时间保护 → 关键词/正则屏蔽 → 重复合并
2. **次级过滤：** 最大行数限制 → 重叠检测

关键词屏蔽：纯文本走 `AhoCorasick` 自动机 O(m+matches)，正则走 Rust `regex` crate。

### 频闪消除与运动平滑

| 优化 | 原理 |
|------|------|
| Snap-based 墙钟时间 | `_displayMediaTime` 以 vsync dt 连续推进；前向漂移 >150ms 时 snap 到媒体时钟（seek/快进），后向 snap 仅在真正时间跳变时触发，两次 snap 间保持单调递增 |
| AnimationController vsync 驱动 | 每个显示帧都触发更新，120Hz+ 显示器运动平滑 |
| 同步帧计算 | `layout()` 是 Dart 同步方法，零异步开销 |
| DPR 缓存 + 像素阈值 ≥2px | Windows 失焦 DPR 微抖动不触发纹理重建 |
| `isNewEngine` 不 resetScene | 避免清除字形图集导致 MSDF 重建阻塞渲染线程 |
| 非阻塞 MSDF 栅格化 | `entry_for()` 返回 None + 4ms 预算异步栅格化 |
| 提交间隔 EMA 自适应门控 | Rust 原生追踪 Dart 提交间隔；EMA ≤20ms（60fps 喂满）时关闭插值，>20ms 时开启补帧 |
| 空帧短路 | 无弹幕时跳过 JSON 编码和 MethodChannel 调用 |
| 超采样 0.0/1.5/2.0 | 低 DPR 设备以 1.5x 或 2x 像素密度渲染后缩放，文字更清晰 |

---

## 项目结构

```
DFM+/
├── rust/                              # Rust 层（crate: dfm-plus）
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs                     # crate 入口
│       ├── dfm_core/                  # 布局算法
│       │   ├── model.rs               # DanmakuItem, GlobalFlags, DanmakuType
│       │   ├── retainer.rs            # 轨道碰撞避让 (proximity-evict)
│       │   ├── filters.rs             # 两级过滤管线
│       │   ├── types.rs               # X 位置计算 (R2L/L2R/固定/特殊)
│       │   ├── factory.rs             # 时长 / 视口缩放
│       │   ├── measure.rs             # 字体度量 (精确 + 启发式)
│       │   └── timer.rs               # 自适应帧率计时器
│       ├── api/
│       │   └── dfm_plus.rs            # 公共 API (prepare_layout + layout_frame)
│       └── render_engine/             # GPU 渲染引擎
│           ├── mod.rs                 # 引擎入口 (include + 模块声明)
│           ├── ffi.rs                 # C FFI 绑定
│           ├── present.rs             # 平台呈现目标
│           └── engine/
│               ├── runtime.rs         # 设备上下文、引擎注册表
│               ├── rendering.rs       # 字形图集、MSDF 栅格化
│               ├── renderer_core.rs   # 渲染器核心 (update_frame, draw)
│               ├── renderer_draw.rs   # build_vertices, 插值门控
│               ├── frame.rs           # 帧数据反序列化
│               └── shaders.rs         # WGSL 着色器
│
├── flutter/                           # Flutter Widget 层
│   ├── pubspec.yaml
│   └── lib/dfm_plus/
│       ├── danmaku_types.dart         # 数据类型定义
│       ├── dfm_plus_overlay.dart      # DfmPlusOverlay Widget
│       ├── dfm_plus_layout_bridge.dart # 布局桥接 (增量配置 + 同步帧计算)
│       ├── dfm_texture_bridge.dart    # GPU 纹理桥接 (MethodChannel)
│       ├── dfm_emoji_pipeline.dart    # Emoji 栅格化管线
│       ├── dfm_platform_support.dart  # 平台支持检测
│       └── dfm_plus_api.dart          # Rust API 类型定义
│
└── README.md
```

---

## 可配置参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `fontSize` | double | 25.0 | 弹幕字号（像素） |
| `displayArea` | double | 1.0 | 显示区域占画面高度比例 (0.1~1.0) |
| `scrollDurationSeconds` | double | 5.0 | 滚动弹幕通过屏幕的时间 |
| `trackGapRatio` | double | 0.15 | 轨道间距 = 弹幕高度 × 该比例 |
| `outlineWidth` | double | 0.0 | 文字描边宽度 (0.0~4.0) |
| `allowStacking` | bool | false | 允许弹幕堆叠（关闭碰撞避让） |
| `mergeDanmaku` | bool | false | 合并重复弹幕为 "xN" |
| `maxQuantity` | int? | null | 最大同屏弹幕数 |
| `maxLinesPerType` | int? | null | 每种类型最大轨道数 |
| `blockWords` | List\<String\> | [] | 关键词/正则屏蔽列表 |
| `isPlaying` | bool | required | 播放状态 |
| `playbackRate` | double | required | 播放倍速 |
| `supersampleMultiplier` | double | 2.0 | 超采样倍率：0.0=关闭, 1.5=1.5x, 2.0=2x |

---

## 构建

```bash
# Rust 层
cd rust
cargo build
cargo test   # 55+ 单元测试

# Flutter 层
cd flutter
flutter pub get
flutter run
```

---

## 致谢

- [DanmakuFlameMaster](https://github.com/Bilibili/DanmakuFlameMaster) — B 站开源 Android 弹幕引擎，DFM+ 的算法来源 (Apache-2.0)
- [NipaPlay-Reload](https://github.com/AimesSoft/NipaPlay-Reload) — DFM+ 的集成宿主项目

## License

Apache License 2.0 — Copyright (c) 2026 Retr0
