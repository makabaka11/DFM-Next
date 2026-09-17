import 'package:flutter_test/flutter_test.dart';
import 'package:dfm_plus_demo/demo_danmaku.dart';

void main() {
  test('demo data spans five minutes and exercises every supported basic mode', () {
    final data = buildDemoDanmaku();
    expect(data.length, greaterThan(300));
    expect((data.first['time'] as num).toDouble(), lessThan(1));
    expect((data.last['time'] as num).toDouble(), greaterThan(299));
    expect(data.map((item) => item['type']).toSet(), containsAll([1, 4, 5, 6]));
  });
}
