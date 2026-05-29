# DFM-Next (代号 DFM+)

> **预计算布局 + Rust 计算层 + Flutter 渲染层** 的弹幕引擎，从 B 站开源 [DanmakuFlameMaster](https://github.com/Bilibili/DanmakuFlameMaster) 算法 1:1 移植，在 [NipaPlay-Reload](https://github.com/nipaplay/NipaPlay-Reload) 中实验性集成。

---

## 架构总览

```
┌─────────────────────────────────────────────────────────┐
│  Flutter 渲染层                                           │
│  ┌───────────────────┐  ┌──────────────────────────────┐ │
│  │ DfmPlusOverlay    │──│ TextureRenderBridge (GPU纹理) │ │
│  │ (Widget 树)       │  │ / Canvas fallback             │ │
│  └────────┬──────────┘  └──────────────────────────────┘ │
│           │ layout() → List<PositionedDanmakuItem>       │
│  ┌────────▼──────────┐                                   │
│  │ DfmPlusLayoutBridge│  增量更新 / 参数变化检测          │
│  └────────┬──────────┘                                   │
├───────────┼──────────────────────────────────────────────┤
│  Rust 计算层 (cdylib + staticlib + rlib)                 │
│  ┌────────▼──────────────────────────────────────────┐   │
│  │ dfm_plus_prepare_layout()  ← 一次性预计算           │   │
│  │   ├─ FilterSystem.filter_primary()                 │   │
│  │   ├─ DanmakuRetainer.fix() (轨道碰撞避让)           │   │
│  │   ├─ 重复合并 / 二分排序 / cache_key 生成            │   │
│  │   └─ → DfmPlusPreparedLayout                       │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ dfm_plus_layout_frame()  ← 每帧查询 (O(log N))     │   │
│  │   ├─ lower_bound / upper_bound 二分定位             │   │
│  │   ├─ X 坐标线性计算                                 │   │
│  │   ├─ FrameCache LRU 缓存                           │   │
│  │   └─ → DfmPlusFrameLayout                          │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**核心思想：** 原版 DFM 每帧实时遍历 TreeSet 做过滤+碰撞+布局，DFM+ 将全部布局计算前移到 `prepare_layout` 阶段一次性完成，每帧仅需 O(log N) 二分查找 + 线性 X 坐标计算，帧开销极低。

---

## 支持的弹幕类型

| 类型 | 代码 | 说明 | 位置计算 | 持续时间 |
|------|------|------|----------|----------|
| ScrollRL | 1 | 右→左滚动弹幕 | `x = view_width - elapsed × step_x` | 可配置 |
| ScrollLR | 6 | 左→右滚动弹幕 | `x = elapsed × step_x - paint_width` | 可配置 |
| FixTop | 5 | 顶部固定弹幕 | 水平居中 | 3.8s |
| FixBottom | 4 | 底部固定弹幕 | 水平居中 | 3.8s |
| Special | 7 | 路径动画弹幕 | 多段线性插值 + alpha 渐变 | 可配置 |

每条弹幕的滚动速度独立计算：`step_x = (view_width + paint_width) / duration_ms`，长度不同的弹幕速度不同，碰撞检测会正确处理速度差异。

---

## 核心算法详解

### 1. 轨道分配引擎 (Retainer)

移植自原版 `DanmakusRetainer`，将画面垂直方向划分为等高的水平轨道，每种弹幕类型（滚动 R2L / 滚动 L2R / 顶部固定 / 底部固定）独立维护轨道数组：

```
track_height = paint_height + paint_height × track_gap_ratio
track_count  = floor(effective_height / track_count)

有效高度规则：
  滚动弹幕 → min(display_area, 0.75) × view_height
  固定弹幕 → display_area × view_height
```

**滚动弹幕分配策略：**
1. 压缩过期条目（`compact_scroll_tracks`）
2. 遍历轨道，用 `scroll_entries_collide()` 检测碰撞
3. 找到无碰撞轨道则放置
4. 全部碰撞时执行 **overwrite 策略**：在上方 60% 轨道中找最小右边缘的轨道，清除并替换（模拟原版 `overwriteInsert`）
5. 自己发送的弹幕（`is_me`）始终强制替换第 0 轨道

**固定弹幕分配策略：**
1. 遍历轨道，检查新弹幕的开始时间是否晚于轨道最后一条的结束时间
2. 时间不重叠则追加到同一轨道
3. 全部占用时 **排队** 到最早结束的轨道：`item.time_ms = earliest_end`，被挤占的旧弹幕标记为已过滤

### 2. 碰撞检测 (Collision)

1:1 移植自原版 `DanmakuUtils.willHitInDuration()`：

```
will_hit_in_duration(d1, d2, view_width):
  if type(d1) ≠ type(d2): return false        // 不同类型永不碰撞
  if d2.start ≤ d1.start: return true          // 同时出现必碰撞
  if d2.start - d1.start ≥ d1.duration: return false  // 时间窗口不重叠

  // 滚动弹幕：在两个时间点做几何碰撞检测
  check_at_time(d1, d2, d2.start_time)         // d2 出现时
  || check_at_time(d1, d2, d1.end_time)        // d1 消失时

check_at_time:
  rect1 = get_rect_at(d1, time)
  rect2 = get_rect_at(d2, time)
  ScrollRL: hit = rect2.left < rect1.right     // 后者追上前者
  ScrollLR: hit = rect2.right > rect1.left     // 后者追上前者
```

**关键改进（相比原版 DFM）：**
- 每条弹幕有独立的 `step_x`（基于自身长度和时长），碰撞检测精确处理不同速度的弹幕
- 使用纯函数式时间窗口判定，不依赖当前帧时间，适用于预计算架构
- 参数顺序自动排序（较早弹幕作为 d1），结果与调用顺序无关

### 3. 过滤系统 (Filters)

移植自原版 `DanmakuFilters`，实现两级过滤管线：

**主过滤（`filter_primary`，布局前执行）：**

| 顺序 | 过滤器 | filter_param | 移植来源 |
|------|--------|-------------|----------|
| 1 | 类型屏蔽 | 1 | `TypeDanmakuFilter` |
| 2 | 数量密度 | 2 | `QuantityDanmakuFilter` |
| 3 | 帧时间保护 | 3 | `ElapsedTimeFilter` |
| 4 | 关键词屏蔽 | 4 | `KeywordFilter` |
| 5 | 重复合并 | 5 | `DuplicateMergingFilter` |

**次级过滤（`filter_secondary`，碰撞检测后执行）：**
- 最大行数限制（`MaximumLinesFilter`）
- 重叠检测（`OverlappingFilter`）

**数量密度算法（移植自 `QuantityDanmakuFilter`）：**
```
filter_factor = 1.0 / (max_size + max_size / 5)
if gap < scroll_duration × filter_factor → 过滤
```

**重复合并算法（移植自 `DuplicateMergingFilter`）：**
- 10 秒滑动窗口内首次出现 → 放行并记录
- 同窗口内再次出现 → 加入 blocked 集合，后续全部过滤

### 4. 时长计算与视口缩放 (Factory)

移植自原版 `DanmakuFactory.updateViewportState()`：

```
scroll_duration = COMMON_DURATION(3800ms) × speed_factor × (viewport_width / BILI_PLAYER_WIDTH(682px))
                 clamped to [MIN(4000ms), MAX(9000ms)]

fixed_duration = 3800ms (常量)
```

以 B 站播放器参考宽度 682px 为基准等比缩放，确保不同分辨率下弹幕视觉速度一致。

### 5. 字体度量 (Measure)

**双模式策略：**

| 模式 | 使用场景 | 实现 |
|------|---------|------|
| 精确模式 | Flutter 侧预测量后传入 `paint_width/paint_height` | GPU 渲染器的 `glyph_hor_advance` 像素级精度 |
| 启发式回退 | `paint_width=0` 时自动启用 | CJK=1.0em, ASCII=0.55em, 空白=0.35em |

描边宽度处理：`final_width = raw_width + outline_px × 2`（仅水平扩展，垂直不加描边避免浪费轨道空间）

GPU 渲染器的描边像素公式：`outline_px = clamp(font_size × 0.06, 1.0, 2.6) × clamp(outline_width, 0.0, 4.0)`

### 6. 三级布局缓存 (Cache)

受原版 `CacheManagingDrawTask` 三级 Bitmap 缓存启发，DFM+ 实现了布局数据的缓存：

| 层级 | 缓存键 | 策略 | 容量 |
|------|--------|------|------|
| Tier 1 (严格) | FNV-1a(text) + color + font_size + type | 完全命中直接复用 | 2000 条 |
| Tier 2 (模糊) | 尺寸容差 (±4px 宽, ±2px 高) | 复用 buffer | 500 条 |
| Tier 3 (未命中) | — | 重新计算 | — |

此外，`layout_frame` 阶段实现了 **帧级 LRU 缓存**（256 条），以量化时间（1/60s 精度）+ layout cache_key 为键，避免相同时间戳的重复计算。

### 7. 自适应帧率计时器 (Timer)

移植自原版 `DrawHandler.syncTimer()`：

```
1. 追踪最近 500 帧的渲染时间
2. 计算平均渲染时间 avg_time
3. gap_time = real_time - timer_time

   if gap_time > 2s → 跳帧直接追赶
   else:
     d = avg_time + gap_time / (1000 / frame_rate)
     d = clamp(d, frame_update_rate, cordon_time)   // [16.67ms, 33.33ms]

4. 平滑：delta 变化 3~8ms 内保持前一帧增量（避免抖动）
5. remaining_time = gap_time - d（累积时间债务）
```

### 8. 全局脏标记 (GlobalFlags)

移植自原版 `GlobalFlagValues`，使用 epoch 递增模式避免逐条遍历：

```rust
struct GlobalFlags {
    measure_flag: u64,    // 字体度量失效
    visible_flag: u64,    // 可见性失效
    filter_flag: u64,     // 过滤状态失效
    first_shown_flag: u64,// 首次显示标记
    sync_offset_flag: u64,// 时间偏移同步
    prepare_flag: u64,    // 准备状态
}
```

只需递增全局 epoch，所有 per-item 的标记自然失效，无需遍历集合。

---

## 项目结构

```
DFM-Next/
├── rust/                              # Rust 计算层（独立 crate: dfm-plus）
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs                     # crate 入口 (pub mod dfm_core, api)
│       ├── dfm_core/                  # 核心算法模块
│       │   ├── mod.rs
│       │   ├── model.rs               # DanmakuItem, Duration, GlobalFlags, DanmakuType
│       │   ├── retainer.rs            # DanmakuRetainer — 轨道碰撞避让引擎
│       │   ├── collision.rs           # will_hit_in_duration() — 碰撞检测
│       │   ├── filters.rs             # FilterSystem — 两级过滤管线
│       │   ├── types.rs               # X 位置计算 (R2L/L2R/固定/特殊路径)
│       │   ├── factory.rs             # 时长计算 / 视口缩放 / 描边像素
│       │   ├── measure.rs             # 启发式字体度量 + HeuristicMeasurer
│       │   ├── cache.rs               # 三级布局缓存 + FNV-1a
│       │   └── timer.rs               # AdaptiveTimer — 自适应帧率计时器
│       └── api/
│           ├── mod.rs
│           └── dfm_plus.rs            # 公共 API + 帧缓存 + 二分查找
│
├── flutter/                           # Flutter 渲染层
│   ├── pubspec.yaml
│   └── lib/
│       └── dfm_plus/
│           ├── danmaku_types.dart     # DanmakuContentItem, PositionedDanmakuItem
│           ├── dfm_plus_layout_bridge.dart  # DfmPlusLayoutBridge — 增量配置 + FFI 调用
│           └── dfm_plus_overlay.dart  # DfmPlusOverlay — Widget + TextureRenderBridge
│
├── LICENSE                            # MIT License
└── README.md
```

---

## 与原版 DanmakuFlameMaster 的全面对比

### 架构对比

| 维度 | 原版 DFM (Java/Android) | DFM-Next (Rust/Flutter) |
|------|------------------------|-------------------------|
| 计算语言 | Java | Rust (零 GC, 零运行时开销) |
| 渲染方式 | CPU 软渲染 → Bitmap → Canvas | GPU 纹理 (MTSDF + wgpu) / Canvas fallback |
| 布局模式 | **实时逐帧计算**：每帧 TreeSet.subSet() → 过滤 → 碰撞 → 布局 | **预计算 + 逐帧查询**：一次 prepare → 帧级二分查找 |
| 线程模型 | UI 线程 + HandlerThread (缓存构建) + UpdateThread | Flutter UI 线程 + Rust FFI 调用 |
| 平台 | Android 仅限 | macOS / iOS / Android / Windows / Linux |

### 算法对比

| 算法模块 | 原版 DFM | DFM-Next | 差异说明 |
|---------|---------|----------|---------|
| **碰撞检测** | `DanmakuUtils.willHitInDuration()` 两点矩形重叠 | 1:1 移植，独立 `step_x` 精确处理速度差异 | 原版所有弹幕共享 speed_factor，DFM-Next 每条弹幕独立计算 |
| **轨道分配** | `DanmakusRetainer` 按 Y 排序遍历 + overwrite | 1:1 移植，按类型独立轨道数组 + overwrite 策略 | 结构化为显式轨道数组，避免线性扫描 |
| **过滤系统** | 10 种运行时过滤器，渲染循环中实时执行 | 移植 5 种核心过滤器，布局阶段一次执行 | 移植了 Type/Quantity/ElapsedTime/Keyword/Duplicate |
| **时长计算** | `DanmakuFactory.updateViewportState()` | 1:1 移植，相同公式和常量 | 完全一致 |
| **字体度量** | `Paint.measureText()` 系统原生精度 | ttf-parser 精确 + 启发式回退 | 可选 GPU 渲染器预测量传入，精度更高 |
| **帧率自适应** | `DrawHandler.syncTimer()` 500帧平均 + 跳帧 | 移植 `AdaptiveTimer` | 可在 Flutter 侧启用 |
| **脏标记** | `GlobalFlagValues` epoch 递增 | 1:1 移植 `GlobalFlags` | 完全一致 |

### 性能对比

| 指标 | 原版 DFM | DFM-Next |
|------|---------|----------|
| 单帧布局复杂度 | O(N × M) 遍历所有可见弹幕 × 轨道 | O(log N) 二分查找 + O(K) 可见弹幕 |
| 碰撞检测调用 | 每帧每条弹幕对每条轨道 | 仅 prepare 阶段一次 |
| 内存分配 | 每帧创建临时对象 (Rect, Paint) | prepare 阶段分配，帧查询零分配 |
| 缓存 | 三级 Bitmap 缓存 + 对象池 | 三级布局缓存 + 帧级 LRU |
| 渲染 | CPU Canvas (受弹幕密度限制) | GPU 并行 (高密度下优势明显) |

### 功能对比

| 功能 | 原版 DFM | DFM-Next |
|------|:--------:|:--------:|
| R2L 滚动弹幕 | ✅ | ✅ |
| L2R 滚动弹幕 | ✅ | ✅ |
| 顶部固定弹幕 | ✅ | ✅ |
| 底部固定弹幕 | ✅ | ✅ |
| 特殊路径动画 (mode7) | ✅ (贝塞尔+3D旋转+缩放+alpha) | ✅ (多段线性插值+alpha渐变) |
| 数量密度控制 | ✅ `QuantityDanmakuFilter` | ✅ 移植 |
| 帧时间保护 | ✅ `ElapsedTimeFilter` | ✅ 移植 |
| 重复合并 | ✅ `DuplicateMergingFilter` | ✅ 移植 |
| 最大行数限制 | ✅ `MaximumLinesFilter` | ✅ 移植 |
| 重叠检测 | ✅ `OverlappingFilter` | ✅ 移植 |
| 关键词过滤 | ✅ | ✅ 移植 |
| 类型过滤 | ✅ | ✅ 移植 |
| 优先级系统 | ✅ priority > 0 跳过过滤 | 🔲 (模型字段已预留) |
| 用户 ID 过滤 | ✅ `UserFilter` | 🔲 |
| 颜色过滤 | ✅ `ColorFilter` | 🔲 |
| AI 剧透过滤 | — | ✅ (NipaPlay-Reload 集成) |
| 跨平台 | Android only | macOS/iOS/Android/Win/Linux |

---

## 快速开始

### Rust 计算层（独立使用）

```rust
use dfm_plus::api::dfm_plus::*;

// 准备弹幕数据
let request = DfmPlusPrepareRequest {
    items: vec![
        DfmPlusDanmakuItem {
            time_seconds: 5.0,
            text: "前方高能".into(),
            type_code: 1,           // ScrollRL
            color_argb: 0xFFFFFFFF,
            is_me: false,
            paint_width: 0.0,       // 0 = 自动使用启发式度量
            paint_height: 0.0,
        },
        DfmPlusDanmakuItem {
            time_seconds: 5.0,
            text: "顶部公告".into(),
            type_code: 5,           // FixTop
            color_argb: 0xFFFF0000,
            is_me: false,
            paint_width: 120.0,     // 正值 = 使用精确度量
            paint_height: 30.0,
        },
    ],
    width: 1920.0,
    height: 1080.0,
    font_size: 25.0,
    display_area: 0.75,
    scroll_duration_seconds: 5.0,
    allow_stacking: false,
    merge_danmaku: false,
    max_quantity: None,
    max_lines_per_type: None,
    track_gap_ratio: 0.15,
    outline_width: 1.5,
};

// 一次性布局计算（过滤 + 碰撞避让 + 轨道分配）
let layout = dfm_plus_prepare_layout(request)?;

// 逐帧位置查询（O(log N) 二分查找 + X 坐标计算）
let frame = dfm_plus_layout_frame(DfmPlusFrameRequest {
    layout,
    current_time_seconds: 6.0,
});

for item in &frame.items {
    println!("[{}] x={:.1} y={:.1}", item.text, item.x, item.y);
}
```

### 批量文本宽度测量

```rust
// 单条测量
let width = dfm_plus_measure_text_width("测试弹幕".into(), 25.0, None)?;

// 批量测量（摊销调用开销）
let widths = dfm_plus_measure_text_widths(
    vec!["短".into(), "这是一条很长的弹幕内容".into()],
    25.0,
    None,
)?;

// 获取字体度量
let metrics = dfm_plus_font_metrics(25.0, 1.5, None)?;
println!("ascent={:.1}, descent={:.1}, line_height={:.1}, outline={:.1}",
    metrics.ascent, metrics.descent, metrics.line_height, metrics.outline_px);
```

### Flutter 渲染层

```dart
DfmPlusOverlay(
  danmakuList: danmakuList,           // List<Map<String, dynamic>>
  danmakuListVersion: version,        // 版本号变更触发重新布局
  playbackTimeMs: playbackNotifier,   // ValueListenable<double>
  currentTimeSeconds: currentTime,
  fontSize: 25.0,
  displayArea: 0.75,
  scrollDurationSeconds: 5.0,
  allowStacking: false,
  mergeDanmaku: false,
  trackGapRatio: 0.15,
  outlineWidth: 1.5,
  shadowStyle: DanmakuShadowStyle.medium,
  opacity: 1.0,
  isVisible: true,
  textureBridge: myTextureBridge,     // 可选：GPU 纹理渲染
  emojiPipeline: myEmojiPipeline,     // 可选：Emoji 渲染管线
  onLayoutCalculated: (items) { ... }, // 布局结果回调
)
```

**Bridge 增量更新机制：**
`DfmPlusLayoutBridge.configure()` 检测以下参数变化，仅在必要时重新计算布局：
- 弹幕列表 identity / 版本号
- fontSize / displayArea / mergeDanmaku / trackGapRatio / outlineWidth
- 自定义字体文件路径
- 视口尺寸 / scrollDurationSeconds

---

## 可配置参数

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| `fontSize` | f64 | 25.0 | 1.0+ | 弹幕字号（像素） |
| `displayArea` | f64 | 1.0 | 0.1~1.0 | 弹幕显示区域占画面高度比例 |
| `scrollDurationSeconds` | f64 | 5.0 | 1.0+ | 滚动弹幕通过屏幕的时间 |
| `trackGapRatio` | f64 | 0.15 | 0.0~2.0 | 轨道间距 = 弹幕高度 × 该比例 |
| `outlineWidth` | f64 | 0.0 | 0.0~4.0 | 文字描边宽度（影响碰撞检测） |
| `allowStacking` | bool | false | - | 允许弹幕堆叠（关闭碰撞避让） |
| `mergeDanmaku` | bool | false | - | 合并重复弹幕为 "xN" |
| `maxQuantity` | u32? | null | - | 最大同屏弹幕数（密度控制） |
| `maxLinesPerType` | u32? | null | - | 每种类型最大轨道数 |

---

## 数据流

```
1. 弹幕列表 (List<Map>)
      │
      ▼
2. DfmPlusLayoutBridge.configure()
   ├─ 解析文本/类型/颜色
   ├─ dfm_plus_measure_text_widths() → 精确宽度
   ├─ dfm_plus_font_metrics() → 行高/描边
   └─ dfm_plus_prepare_layout()
       ├─ 构建 DanmakuItem 列表
       ├─ FilterSystem.filter_primary() → 5 种过滤器
       ├─ DanmakuRetainer.fix() → 轨道碰撞避让
       ├─ 重复合并 → "xN"
       ├─ 排序 → item_times + items (O(log N) 二分查找就绪)
       └─ → DfmPlusPreparedLayout
      │
      ▼
3. 每帧: DfmPlusLayoutBridge.layout(currentTimeSeconds)
   └─ dfm_plus_layout_frame()
       ├─ FrameCache LRU 命中检查
       ├─ lower_bound / upper_bound → 可见弹幕范围
       ├─ 线性计算 X 坐标
       └─ → List<DfmPlusFrameItem>
      │
      ▼
4. DfmPlusOverlay._tryUpdateTexture()
   ├─ TextureRenderBridge.setFrame() → GPU 渲染
   └─ Flutter Texture widget 显示
```

---

## 性能特征

| 特性 | 说明 |
|------|------|
| **预计算架构** | `prepare_layout` 一次性完成全部碰撞检测和轨道分配，`layout_frame` 仅做二分查找 + X 坐标计算 |
| **O(log N) 帧查询** | 按时间排序的 `item_times` 数组 + 自实现 `lower_bound` / `upper_bound` |
| **帧级 LRU 缓存** | 256 条容量，量化时间键（1/60s 精度），相同时间戳直接命中 |
| **布局缓存** | 三级缓存（严格 FNV-1a / 模糊尺寸 / 未命中），避免重复度量计算 |
| **增量更新** | Bridge 层 8 项参数变化检测，仅必要时重新调用 `prepare_layout` |
| **轨道压缩** | `compact_scroll_tracks` 在每次放置前清除过期条目 |
| **零运行时依赖** | Rust crate 无任何第三方依赖（dev-dependencies 除外） |

---

## 构建

```bash
# Rust 计算层
cd rust
cargo build                    # 编译
cargo test                     # 运行全部单元测试（60+ 测试用例）

# Flutter 渲染层（需要 flutter_rust_bridge 生成 FFI 绑定）
cd flutter
flutter pub get
flutter run
```

**集成到 NipaPlay-Reload：**
1. 在 NipaPlay-Reload 中通过 `flutter_rust_bridge` 生成 Rust → Dart 绑定
2. 确保 Rust 运行时已初始化
3. 使用 `DfmPlusOverlay` Widget 替换原有弹幕覆盖层

---

## 致谢

- [DanmakuFlameMaster](https://github.com/Bilibili/DanmakuFlameMaster) — B 站开源 Android 弹幕引擎，DFM-Next 的算法来源（Apache-2.0 License）
- [NipaPlay-Reload](https://github.com/nipaplay/NipaPlay-Reload) — DFM-Next 的实验性集成宿主项目

## License

MIT License — Copyright (c) 2025 NipaPlay
