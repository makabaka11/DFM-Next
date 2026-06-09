# DFM-Next (代号 DFM+)

> **预计算布局 + Rust 计算层 + Flutter 渲染层** 的弹幕引擎，从 B 站开源 [DanmakuFlameMaster](https://github.com/Bilibili/DanmakuFlameMaster) 算法 1:1 移植，在 [NipaPlay-Reload](https://github.com/AimesSoft/NipaPlay-Reload) 中实验性集成。

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
│  │   ├─ LAYOUT_STORE 句柄查找 (避免序列化整个布局)       │   │
│  │   ├─ partition_point 二分定位                        │   │
│  │   ├─ X 坐标线性计算 (预存 is_scroll/centered_x, ScrollLR 方向感知)       │   │
│  │   └─ → DfmPlusFrameLayout (item_index 零 String 分配)│   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**核心思想：** 原版 DFM 每帧实时遍历 TreeSet 做过滤+碰撞+布局，DFM+ 将全部布局计算前移到 `prepare_layout` 阶段一次性完成，每帧仅需 O(log N) 二分查找 + 线性 X 坐标计算，帧开销极低。`DfmPlusFrameItem` 仅返回 `item_index + x/y/offstage_x` 四个数值字段，Dart 端通过索引从 `PreparedLayout` 取文本和样式，帧查询阶段零 String 堆分配。`DfmPlusPreparedLayout` 通过不透明句柄（`handle: u64`）存储在 Rust 侧 `LAYOUT_STORE` 中，`dfm_plus_layout_frame` 仅传递句柄而非整个布局数据，避免每帧 MB 级序列化开销。Dart 端同步帧计算（`DfmPlusLayoutBridge.layout()`），零异步开销。内部使用 FxHashMap（非密码学安全但 2-3x 更快）替代标准库 HashMap。

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
1. 压缩过期条目（`compact`）：仅保留 `end_ms()` 尚未到达的条目
2. 遍历轨道，空轨道直接放置（O(1) 快速路径）
3. 用 `scroll_entries_collide()` 检测碰撞
4. 找到无碰撞轨道则放置
5. 全部碰撞时执行 **proximity-evict 策略**：保护顶部 40% 轨道（稳定区），在底部 60% 轨道中找最小右边缘的轨道，**仅替换最接近退出的单条弹幕**（而非清除整轨），同时驱逐该轨道上已滚出 85% 以上的弹幕（`EXIT_PROXIMITY_RATIO = 0.15`），中间位置的弹幕继续滚动接受短暂重叠
6. 自己发送的弹幕（`is_me`）始终强制替换第 0 轨道

**固定弹幕分配策略：**
1. 压缩过期条目（`compact_fixed_tracks`）：从轨道前端移除 `end_ms <= current_time` 的条目
2. 遍历轨道，检查新弹幕的开始时间是否晚于轨道最后一条的结束时间
3. 时间不重叠则追加到同一轨道
4. 全部占用时 **丢弃**（不排队不驱逐，保证已有弹幕不被打断）

### 2. 碰撞检测 (Collision)

1:1 移植自原版 `DanmakuUtils.willHitInDuration()`，优化为直接计算 left/right 的内联函数：

```
will_hit_in_duration(d1, d2, view_width):
  if type(d1) ≠ type(d2): return false        // 不同类型永不碰撞
  if d2.start ≤ d1.start: return true          // 同时出现必碰撞
  if d2.start - d1.start ≥ d1.duration: return false  // 时间窗口不重叠

  // 滚动弹幕：在两个时间点做几何碰撞检测
  check_hit_same_type(d1, d2, d2.start_time)   // d2 出现时
  || check_hit_same_type(d1, d2, d1.end_time)  // d1 消失时

check_hit_same_type:
  left1 = entry_left_at(d1, time, view_width)
  right1 = left1 + d1.paint_width
  left2 = entry_left_at(d2, time, view_width)
  right2 = left2 + d2.paint_width
  ScrollRL: hit = left2 < right1              // 后者追上前者
  ScrollLR: hit = right2 > left1              // 后者追上前者
```

**关键改进（相比原版 DFM）：**
- 每条弹幕有独立的 `step_x`（基于自身长度和时长），碰撞检测精确处理不同速度的弹幕
- 使用纯函数式时间窗口判定，不依赖当前帧时间，适用于预计算架构
- 参数顺序自动排序（较早弹幕作为 d1），结果与调用顺序无关
- 消除了原版三层中间调用链（`check_hit_at_time` → `entry_rect_at` → `check_hit`），改为 `check_hit_same_type` + `entry_left_at` 直接计算，减少函数调用开销

### 3. 过滤系统 (Filters)

移植自原版 `DanmakuFilters`，实现两级过滤管线：

**主过滤（`filter_primary`，布局前执行）：**

| 顺序 | 过滤器 | filter_param | 移植来源 |
|------|--------|-------------|----------|
| 1 | 类型屏蔽 | 1 | `TypeDanmakuFilter` |
| 2 | 数量密度 | 2 | `QuantityDanmakuFilter` |
| 3 | 帧时间保护 | 3 | `ElapsedTimeFilter` |
| 4 | 关键词/正则屏蔽 | 4 | `KeywordRegexFilter` |
| 5 | 重复合并 | 5 | `DuplicateMergingFilter` |

**次级过滤（`filter_secondary`，碰撞检测后执行）：**
- 最大行数限制（`MaximumLinesFilter`）
- 重叠检测（`OverlappingFilter`）

**数量密度算法（移植自 `QuantityDanmakuFilter`）：**
```
filter_factor = 1.0 / (max_size + max_size / 5)
if gap < scroll_duration × filter_factor → 过滤
```

**关键词/正则屏蔽（移植自 `KeywordFilter`，扩展正则支持）：**
- 纯文本关键词：`AhoCorasick` 自动机单次遍历匹配所有模式，O(m+matches) 复杂度
- 正则表达式：`规则名称/表达式/` 格式，使用 Rust `regex` crate 编译执行
- 通过 `set_block_words()` 统一设置，自动解析格式并分别构建 `AhoCorasick` 自动机和 `blocked_regexes`

**重复合并算法（移植自 `DuplicateMergingFilter`）：**
- 10 秒滑动窗口内首次出现 → 放行并记录
- 同窗口内再次出现 → 加入 blocked 集合，后续全部过滤
- 惰性清理：仅在 `current_duplicates` 超过 128 条时才执行 `retain`，避免 O(n²) 开销

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

### 6. 帧查询 (Frame Query)

`layout_frame` 阶段执行纯 O(K) 计算（K = 可见弹幕数）：

1. 对 `item_times` 执行 `partition_point` 二分查找，定位当前时间窗口
2. 线性遍历可见弹幕，计算每条的 X 坐标
3. 返回 `DfmPlusFrameLayout`（仅含 `item_index + x/y/offstage_x`，零 String 分配）

**内部 HashMap：** 使用 `FxHashMap`（基于 FxHash，非密码学安全但 2-3x 更快）替代标准库 `HashMap`（SipHash-2-4）。

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

### 9. 频闪消除优化 (Anti-Flicker / Anti-Judder)

滚动弹幕在 60Hz 及以上刷新率下会出现肉眼可见的位置抖动（每帧约 1px 跳动），根本原因是时间精度不足导致帧间位移量交替变化。以下四项优化从时间源、量化精度、缓存策略、异步开销四个层面彻底消除频闪：

#### 高频时钟插值 (High-precision clock interpolation)

播放时间源改用挂钟插值，以 `player.position` 为锚点，实现亚毫秒级精度，而非整数毫秒步进。

```
interpolated_time = anchor + (now - anchor_wall_time)

漂移修正：
  drift = interpolated_time - player.position
  if |drift| > 30ms（seek / 暂停恢复等大跳变）:
    立即重新锚定（snap）
  else:
    interpolated_time -= drift × 0.05   // 每帧修正 5%，渐进收敛
    更新 anchor
```

**效果：** 消除了整数毫秒步进导致的 16/17ms 交替 delta，滚动弹幕不再出现每帧 ~1px 的位置抖动。小漂移通过 5% 渐进修正平滑收敛，大跳变（seek、暂停恢复）立即对齐避免长时间偏移。

#### 移除 60fps 量化 (Remove 60fps quantization)

Dart 侧原先使用 `(currentTime * 60).round()` 将时间量化到 1/60s 网格，这意味着同一 16.67ms 窗口内的所有显示帧共享相同的弹幕位置。在 120Hz 及以上显示器上，60fps 量化会导致每隔一帧弹幕位置完全相同（跳帧），视觉上表现为明显的卡顿。

现已替换为直接浮点时间比较，确保每个显示帧都获得唯一的弹幕位置，120Hz+ 显示器下运动完全平滑。

#### 纯计算无缓存 (Pure computation, no cache)

`build_dfm_plus_frame()` 是纯 O(M) 计算（二分查找 + 位置计算，通常 <0.1ms），不需要帧级缓存。每帧都使用完整时间精度重新计算位置，计算开销可忽略，位置精度最大化。

#### Dart 侧同步帧计算 (Dart-side synchronous frame computation)

每帧位置计算（`build_dfm_plus_frame` 逻辑）已从 Rust FFI 迁移至 Dart 侧同步计算。此前每帧需要一次异步 `await dfmPlusLayoutFrame()` FFI 调用，引入至少一个 microtask 延迟。加上其他异步调用（`configure` + `tryUpdateTexture`），3 条 await 链可能超过 16.67ms 帧预算，导致掉帧和可见卡顿。

现在 `DfmPlusLayoutBridge.layout()` 是同步方法：
- 对 `PreparedLayout.itemTimes`（Float64List）执行二分查找定位可见窗口
- 使用与 Rust `build_dfm_plus_frame` 相同的公式计算每条可见弹幕的 x/y 位置
- 立即返回结果，零异步开销

这与 GPU 渲染引擎的做法一致：`layout()` 是 `CustomPainter.paint()` 内的同步调用，确保每次显示刷新都获得最新计算的帧。

**Post-configure 时间重读：** `configure()` 是异步操作（Rust prepare + 字体加载），耗时数十到数百毫秒。期间播放位置可能从 0 跳变到恢复点。为避免绘制 t=0 弹幕，`configure()` 完成后立即重新读取 `playbackTimeMs`。

**关键洞察：** `build_dfm_plus_frame` 是纯 O(M) 计算（二分查找 + 位置数学，即使 Dart 执行通常也 <0.1ms），异步 FFI 开销才是瓶颈，而非计算本身。

### 10. UI 交互防闪烁 (Anti-flicker on UI interaction)

当播放页面 UI 元素（控制栏、进度条、悬浮按钮）触发状态更新时，`DfmPlusOverlay` 的 `didUpdateWidget` 会被调用。如果将 `opacity` 和 `isVisible` 变化等同于布局参数变化（触发 `_forceLayout`），会导致不必要的完整 `configure()` 重跑 + 纹理重建，产生可见的弹幕闪烁。

**修复策略：** 将 `didUpdateWidget` 中的属性变化分为三级：

| 变化类型 | 触发条件 | 处理方式 |
|---------|---------|---------|
| 布局参数变化 | 弹幕列表、字号、显示区域、轨道间距等 | `_forceLayout = true` + `_queueUpdate()` — 完整重配置 |
| 可见性变化 | `isVisible` 切换 | 仅 `_queueUpdate()` — 轻量更新，跳过 `configure()` |
| 展示层变化 | `opacity` 变化 | 无需更新 — 由 `build()` 中的 `Opacity` widget 处理 |

**Windows 抖动保护：** Windows 平台在窗口失焦时会触发 `didChangeMetrics` 回调，导致 DPR 微小抖动（±0.001）。为避免不必要的纹理重建和引擎重置：

- 布局尺寸变化 >=2px 才触发 `_forceLayout`（亚像素抖动不重算布局）
- DPR 变化仅更新缓存值，不触发 `_forceLayout`（DPR 仅影响纹理像素大小，不影响弹幕布局）
- 纹理重建阈值 >=2px（避免 ±1px 像素抖动触发 `ensureTexture` → `isNewEngine` → `resetScene` → 闪烁）

### 11. 对象复用优化 (Object reuse)

每帧 `layout()` 调用原先会创建新的 `List<PositionedDanmakuItem>` 和 `DanmakuContentItem` 对象，造成频繁 GC。现已实现两层复用：

- **布局缓冲区** (`_layoutBuffer`)：`layout()` 方法清空并复用同一个 `List`，避免每帧分配新列表
- **内容缓存** (`_contentCache`)：以 prepared item index 为键缓存 `DanmakuContentItem`（含 `Color` 对象），同一弹幕在多帧间复用同一内容对象，仅更新 `x`/`y`/`offstageX` 位置字段

### 12. 超采样渲染 (Supersample rendering)

在部分设备（平板、桌面端 DPR < 2.0）上，弹幕纹理以 2x 像素密度渲染，使文字更清晰。通过 `enableSupersample` 构造参数控制，集成方可根据设备类型和用户偏好决定是否启用。

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
│       │   ├── model.rs               # DanmakuItem, Duration, GlobalFlags, EpochFlags, DanmakuType
│       │   ├── retainer.rs            # DanmakuRetainer — 轨道碰撞避让引擎 (SmallVec)
│       │   ├── filters.rs             # FilterSystem — 两级过滤管线 (FxHashMap + 惰性清理)
│       │   ├── types.rs               # X 位置计算 (R2L/L2R/固定/特殊路径)
│       │   ├── factory.rs             # 时长计算 / 视口缩放 / 描边像素
│       │   ├── measure.rs             # 启发式字体度量 + HeuristicMeasurer（无锁）
│       │   └── timer.rs               # AdaptiveTimer — 自适应帧率计时器
│       └── api/
│           ├── mod.rs
│           └── dfm_plus.rs            # 公共 API (FxHashMap LAYOUT_STORE + partition_point)
│
├── flutter/                           # Flutter 渲染层
│   ├── pubspec.yaml
│   └── lib/
│       └── dfm_plus/
│           ├── danmaku_types.dart     # DanmakuContentItem, PositionedDanmakuItem
│           ├── dfm_plus_api.dart      # Rust API 类型定义（需 flutter_rust_bridge 生成实际绑定）
│           ├── dfm_plus_layout_bridge.dart  # DfmPlusLayoutBridge — 增量配置 + 同步帧计算
│           └── dfm_plus_overlay.dart  # DfmPlusOverlay — Widget + 抽象接口 (TextureRenderBridge, EmojiRenderPipeline, OverlayViewport)
│
├── LICENSE                            # Apache License 2.0
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
| **碰撞检测** | `DanmakuUtils.willHitInDuration()` 两点矩形重叠 | 1:1 移植 + 内联优化，独立 `step_x` 精确处理速度差异，5 参数方向感知位置比较 | 原版所有弹幕共享 speed_factor，DFM-Next 每条弹幕独立计算；消除了三层中间调用链 |
| **轨道分配** | `DanmakusRetainer` 按 Y 排序遍历 + overwrite | 1:1 移植，按类型独立轨道数组 + 顶部 40% 保护 + 底部 60% proximity-evict 策略 | 结构化为显式轨道数组，仅替换最接近退出的单条弹幕 |
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
| 缓存 | 三级 Bitmap 缓存 + 对象池 | FxHashMap + 对象复用 (_layoutBuffer / _contentCache) |
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
| 关键词过滤 | ✅ | ✅ 移植 + 正则扩展 |
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
    layout_handle: layout.handle,
    current_time_seconds: 6.0,
});

for fi in &frame.items {
    let pi = &layout.items[fi.item_index as usize];
    println!("[{}] x={:.1} y={:.1}", pi.text, fi.x, fi.y);
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
  blockWords: const [],              // 关键词/正则屏蔽列表
  enableSupersample: false,          // 超采样渲染（平板/低DPR设备建议开启）
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
| `blockWords` | List\<String\> | [] | - | 关键词/正则屏蔽列表 |
| `enableSupersample` | bool | false | - | 超采样渲染（2x 像素密度，平板/低DPR设备建议开启） |

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
   └─ 同步帧计算 (Dart 侧)
       ├─ partition_point → 可见弹幕范围
       ├─ 线性计算 X 坐标
       └─ → List<PositionedDanmakuItem>
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
| **O(log N) 帧查询** | 按时间排序的 `item_times` 数组 + 标准库 `partition_point` 二分查找 |
| **FxHashMap** | 全局替换标准库 HashMap/HashSet，非密码学安全但 2-3x 更快 |
| **SmallVec** | overwrite 路径 `SmallVec<[usize; 4]>` 替代 `Vec<usize>`，少量 displaced 时零堆分配 |
| **惰性清理** | `filter_duplicate` 的 `retain` 仅在 HashMap 超过 128 条时执行，消除 O(n²) |
| **帧查询零分配** | `DfmPlusFrameItem` 仅含 `item_index + x/y/offstage_x`，无 String clone，通过索引从 PreparedLayout 取样式 |
| **不透明句柄** | `DfmPlusPreparedLayout.handle` + Rust 侧 `LAYOUT_STORE`，帧查询仅传递 8 字节句柄，避免每帧 MB 级布局序列化 |
| **预存计算** | `is_scroll` + `centered_x` 预计算，帧查询消除 type match 和重复除法 |
| **EpochFlags** | 6 个 epoch flag 合并为结构体，方便后续冷热数据拆分 |
| **正则过滤** | `规则名称/表达式/` 格式自动解析为 `regex::Regex`，纯文本关键词走 `AhoCorasick` 自动机单次匹配 |
| **增量更新** | Bridge 层 8 项参数变化检测，仅必要时重新调用 `prepare_layout` |
| **轨道压缩** | `compact` 在每次放置前清除过期条目，`last_compact_ms` 跳过同时间重复压缩 |
| **轻量依赖** | Rust crate 仅依赖 `rustc-hash` + `smallvec` + `regex` + `aho-corasick`（dev-dependencies 除外） |
| **零 clone 排序** | in-place sort 替代索引排序 + clone，`mem::take` 替代 text clone，`into_iter` 替代 `iter` + clone |
| **单次遍历合并** | 重复合并从三步（建 HashMap → 标记 → 计数）合并为单次遍历 + 延迟标记 |
| **合并碰撞扫描** | `select_scroll_track` 将碰撞检测和 overwriteInsert 的 min_right_edge 计算合并为单次遍历 |
| **类型预分组** | 单次遍历构建按类型索引数组，消除 O(4N) 全量扫描，同时移除冗余 measure() 调用 |
| **Copy 类型** | `GlobalFlags` 和 `Duration` derive Copy，消除 `.clone()` 开销 |
| **统一文本度量** | `measure_text_width_heuristic` 委托 `model::measure_text_width`，使用精确 Unicode 范围判断，消除两处实现不一致 |
| **ScrollLR 方向感知** | 帧渲染区分 ScrollRL (`width - speed*elapsed`) 和 ScrollLR (`speed*elapsed - paint_width`)，修复左→右弹幕位置错误 |
| **固定弹幕简化** | `select_fixed_track` 返回 `Option<usize>`，移除 `was_queued` 死代码和 `displaced_index` 空路径 |
| **UI 交互防闪烁** | `didUpdateWidget` 分级处理：布局参数变化触发完整重配置，`isVisible` 仅轻量更新，`opacity` 由展示层处理 |
| **对象复用** | `_layoutBuffer` 复用列表 + `_contentCache` 复用 `DanmakuContentItem`，帧查询零临时对象分配 |
| **超采样可配置** | `enableSupersample` 构造参数控制 2x 像素密度渲染，集成方可按设备类型和用户偏好启用 |
| **Windows 抖动保护** | 布局尺寸变化 >=2px 才触发重配置，DPR 变化不触发布局重算，纹理重建阈值 >=2px |
| **Post-configure 时间重读** | `configure()` 完成后重新读取播放时间，避免异步期间播放位置跳变导致绘制 t=0 弹幕 |
| **Proximity-evict** | overwrite 策略仅替换最接近退出的单条弹幕 + 驱逐已 85%+ 出屏的条目，避免整轨清除导致的批量消失 |

---

## 构建

```bash
# Rust 计算层
cd rust
cargo build                    # 编译
cargo test                     # 运行全部单元测试（55+ 测试用例）

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
- [NipaPlay-Reload](https://github.com/AimesSoft/NipaPlay-Reload) — DFM-Next 的实验性集成宿主项目

## License

Apache License 2.0 — Copyright (c) 2026 Retr0
