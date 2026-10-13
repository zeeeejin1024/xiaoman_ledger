import 'dart:math' as math;

enum ChartScaleMode { linear, squareRoot }

class ChartScale {
  final ChartScaleMode mode;
  final double maxValue;
  const ChartScale(this.mode, this.maxValue);

  factory ChartScale.from(Iterable<num> values) {
    final list = values.map((v) => v.toDouble()).where((v) => v > 0).toList();
    if (list.isEmpty) return const ChartScale(ChartScaleMode.linear, 1);
    final max = list.reduce(math.max);
    final min = list.reduce(math.min);
    return ChartScale(min > 0 && max / min > 8 ? ChartScaleMode.squareRoot : ChartScaleMode.linear, max);
  }

  double visualValue(double value) => mode == ChartScaleMode.linear
      ? value / maxValue
      : math.sqrt(value / maxValue);

  double trueValue(double visual) => mode == ChartScaleMode.linear
      ? visual * maxValue
      : visual * visual * maxValue;
}
