import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/modules/stats/chart_scale.dart';

void main() {
  test('uses linear scale when ratio is at most eight', () {
    expect(ChartScale.from([80, 10]).mode, ChartScaleMode.linear);
  });
  test('uses square-root visual values above ratio eight', () {
    final scale = ChartScale.from([10000, 100]);
    expect(scale.mode, ChartScaleMode.squareRoot);
    expect(scale.visualValue(100), closeTo(.1, .001));
    expect(scale.trueValue(1), 10000);
  });
}
