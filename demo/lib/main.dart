import 'dart:async';

import 'package:dfm_plus/dfm_plus/danmaku_types.dart';
import 'package:dfm_plus/dfm_plus/dfm_plus_overlay.dart';
import 'package:flutter/material.dart';

import 'demo_danmaku.dart';

void main() => runApp(const DfmDemoApp());

class DfmDemoApp extends StatelessWidget {
  const DfmDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DFM+ 原生 GPU 演示',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF6EE7D2),
    ),
    home: const DemoPlayerPage(),
  );
}

class DemoPlayerPage extends StatefulWidget {
  const DemoPlayerPage({super.key});

  @override
  State<DemoPlayerPage> createState() => _DemoPlayerPageState();
}

class _DemoPlayerPageState extends State<DemoPlayerPage> {
  static const double durationSeconds = 300;
  final ValueNotifier<double> _playbackTimeMs = ValueNotifier(0);
  final TextEditingController _sendController = TextEditingController();
  final TextEditingController _blockController = TextEditingController();
  final Stopwatch _clock = Stopwatch()..start();
  late final Timer _ticker;
  late final List<Map<String, dynamic>> _danmaku = buildDemoDanmaku();
  int _lastTickUs = 0;
  int _listVersion = 1;
  bool _playing = true;
  bool _visible = true;
  double _rate = 1;
  double _fontSize = 30;
  double _opacity = 1;
  double _displayArea = 1;
  double _scrollDuration = 10;
  double _timeOffset = 0;
  double _trackGap = 0.15;
  double _outline = 2;
  double _supersample = 0;
  bool _supersampleInitialized = false;
  bool _allowStacking = false;
  bool _merge = false;
  int? _maxQuantity;
  int? _maxLines;
  DanmakuShadowStyle _shadow = DanmakuShadowStyle.strong;

  @override
  void initState() {
    super.initState();
    _lastTickUs = _clock.elapsedMicroseconds;
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_supersampleInitialized) {
      _supersample = View.of(context).devicePixelRatio < 2.0 ? 2.0 : 0.0;
      _supersampleInitialized = true;
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _playbackTimeMs.dispose();
    _sendController.dispose();
    _blockController.dispose();
    super.dispose();
  }

  void _tick() {
    final nowUs = _clock.elapsedMicroseconds;
    final elapsed = (nowUs - _lastTickUs).clamp(0, 200000) / 1000000;
    _lastTickUs = nowUs;
    if (!_playing) return;
    final next = (_playbackTimeMs.value / 1000 + elapsed * _rate).clamp(
      0.0,
      durationSeconds,
    );
    _playbackTimeMs.value = next * 1000;
    if (next >= durationSeconds) {
      setState(() => _playing = false);
    } else {
      setState(() {});
    }
  }

  void _seek(double seconds) {
    _lastTickUs = _clock.elapsedMicroseconds;
    _playbackTimeMs.value = seconds.clamp(0.0, durationSeconds) * 1000;
    setState(() {});
  }

  void _send() {
    final text = _sendController.text.trim();
    if (text.isEmpty) return;
    final time = _playbackTimeMs.value / 1000;
    _danmaku.add(<String, dynamic>{
      'time': time,
      'content': text,
      'type': 1,
      'color': 0xFFFFF59D,
      'isMe': true,
    });
    _danmaku.sort((a, b) => (a['time'] as num).compareTo(b['time'] as num));
    _sendController.clear();
    setState(() => _listVersion++);
  }

  String _stamp(double seconds) {
    final value = seconds.floor();
    return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final player = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVideoStage(),
        const SizedBox(height: 12),
        _buildControls(),
        const SizedBox(height: 12),
        _buildSendRow(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('DFM+ · 5 分钟原生 GPU 演示'),
        actions: [
          IconButton(
            tooltip: _visible ? '隐藏弹幕' : '显示弹幕',
            icon: Icon(_visible ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: player),
                        const SizedBox(width: 20),
                        SizedBox(width: 330, child: _buildSettings()),
                      ],
                    )
                  : Column(
                      children: [
                        player,
                        const SizedBox(height: 16),
                        _buildSettings(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStage() => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF172E3A),
                    Color(0xFF223D39),
                    Color(0xFF131924),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.movie_filter_outlined,
                      size: 72,
                      color: Color(0x556EE7D2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '伪视频画面 · ${_stamp(_playbackTimeMs.value / 1000)}',
                      style: const TextStyle(color: Color(0x99FFFFFF)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DfmPlusOverlay(
              danmakuList: _danmaku,
              danmakuListVersion: _listVersion,
              playbackTimeMs: _playbackTimeMs,
              currentTimeSeconds: _playbackTimeMs.value / 1000,
              fontSize: _fontSize,
              isVisible: _visible,
              opacity: _opacity,
              displayArea: _displayArea,
              timeOffset: _timeOffset,
              scrollDurationSeconds: _scrollDuration,
              allowStacking: _allowStacking,
              mergeDanmaku: _merge,
              customFontFamily: '',
              customFontFilePath: '',
              outlineWidth: _outline,
              shadowStyle: _shadow,
              trackGapRatio: _trackGap,
              maxQuantity: _maxQuantity,
              maxLinesPerType: _maxLines,
              blockWords: _blockController.text
                  .split(',')
                  .map((word) => word.trim())
                  .where((word) => word.isNotEmpty)
                  .toList(growable: false),
              supersampleMultiplier: _supersample,
              isPlaying: _playing,
              playbackRate: _rate,
            ),
          ),
          Positioned(
            left: 14,
            bottom: 10,
            child: Text(
              'DFM+  ·  ${_danmaku.length} 条弹幕',
              style: const TextStyle(color: Color(0xAAFFFFFF)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildControls() {
    final seconds = _playbackTimeMs.value / 1000;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(_stamp(seconds)),
                Expanded(
                  child: Slider(
                    value: seconds.clamp(0.0, durationSeconds),
                    max: durationSeconds,
                    onChanged: _seek,
                  ),
                ),
                const Text('05:00'),
              ],
            ),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _lastTickUs = _clock.elapsedMicroseconds;
                    setState(() => _playing = !_playing);
                  },
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  label: Text(_playing ? '暂停' : '播放'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '回到开头',
                  onPressed: () => _seek(0),
                  icon: const Icon(Icons.replay),
                ),
                const Spacer(),
                const Text('倍速'),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  value: _rate,
                  items: const [0.5, 1.0, 1.25, 1.5, 2.0, 3.0]
                      .map(
                        (rate) => DropdownMenuItem(
                          value: rate,
                          child: Text('$rate×'),
                        ),
                      )
                      .toList(),
                  onChanged: (rate) {
                    if (rate != null) setState(() => _rate = rate);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendRow() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _sendController,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                labelText: '发送弹幕',
                hintText: '输入内容后回车或点击发送',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _send, child: const Text('发送')),
        ],
      ),
    ),
  );

  Widget _settingSlider(
    String label,
    double value,
    double min,
    double max,
    int decimals,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label  ${value.toStringAsFixed(decimals)}'),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (value) => setState(() => onChanged(value)),
      ),
    ],
  );

  Widget _buildSettings() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('弹幕设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _settingSlider(
            '字号',
            _fontSize,
            14,
            48,
            0,
            (value) => _fontSize = value,
          ),
          _settingSlider(
            '不透明度',
            _opacity,
            0.1,
            1,
            2,
            (value) => _opacity = value,
          ),
          _settingSlider(
            '显示区域',
            _displayArea,
            0.2,
            1,
            2,
            (value) => _displayArea = value,
          ),
          _settingSlider(
            '滚动时长（秒）',
            _scrollDuration,
            3,
            15,
            1,
            (value) => _scrollDuration = value,
          ),
          _settingSlider(
            '时间偏移（秒）',
            _timeOffset,
            -10,
            10,
            1,
            (value) => _timeOffset = value,
          ),
          _settingSlider(
            '轨道间距',
            _trackGap,
            0,
            0.5,
            2,
            (value) => _trackGap = value,
          ),
          SwitchListTile(
            title: const Text('显示弹幕'),
            value: _visible,
            onChanged: (value) => setState(() => _visible = value),
          ),
          SwitchListTile(
            title: const Text('允许堆叠'),
            value: _allowStacking,
            onChanged: (value) => setState(() => _allowStacking = value),
          ),
          SwitchListTile(
            title: const Text('合并重复弹幕'),
            value: _merge,
            onChanged: (value) => setState(() => _merge = value),
          ),
          _choice<double>('描边', _outline, const [
            0,
            1,
            2,
          ], (value) => _outline = value),
          _choice<DanmakuShadowStyle>(
            '阴影',
            _shadow,
            DanmakuShadowStyle.values,
            (value) => _shadow = value,
          ),
          _choice<double>('超采样', _supersample, const [
            0,
            1.5,
            2,
          ], (value) => _supersample = value),
          _choice<int?>('同屏数量上限', _maxQuantity, const <int?>[
            null,
            50,
            100,
            200,
          ], (value) => _maxQuantity = value),
          _choice<int?>('每类型轨道上限', _maxLines, const <int?>[
            null,
            5,
            10,
            20,
          ], (value) => _maxLines = value),
          const SizedBox(height: 8),
          TextField(
            controller: _blockController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '屏蔽关键词',
              hintText: '多个词用逗号分隔',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _choice<T>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T> onChanged,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      DropdownButton<T>(
        value: value,
        items: values
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item == null ? '不限' : '$item'),
              ),
            )
            .toList(),
        onChanged: (item) => setState(() => onChanged(item as T)),
      ),
    ],
  );
}
