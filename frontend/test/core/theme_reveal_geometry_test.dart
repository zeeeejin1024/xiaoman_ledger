import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/theme_reveal_geometry.dart';

void main() {
  test('radius covers every corner for centered and edge origins', () {
    const size = Size(400, 800);
    for (final origin in [
      Offset.zero,
      const Offset(200, 400),
      const Offset(395, 750),
    ]) {
      final radius = themeRevealRadius(size, origin);
      for (final corner in [
        Offset.zero,
        const Offset(400, 0),
        const Offset(0, 800),
        const Offset(400, 800),
      ]) {
        expect(radius, greaterThan((corner - origin).distance));
      }
    }
  });
  test('old image mask covers all before reveal and clears all at end', () {
    const size = Size(400, 800), origin = Offset(300, 650);
    expect(themeRevealMask(size, origin, 0).contains(origin), isTrue);
    expect(themeRevealMask(size, origin, 100).contains(origin), isFalse);
    expect(
      themeRevealMask(size, origin, 100).contains(const Offset(1, 1)),
      isTrue,
    );
    expect(
      themeRevealMask(
        size,
        origin,
        themeRevealRadius(size, origin),
      ).contains(const Offset(1, 1)),
      isFalse,
    );
  });
  test(
    'system bars change only when their entire region has been revealed',
    () {
      const origin = Offset(200, 650), top = Rect.fromLTWH(0, 0, 400, 24);
      const bottom = Rect.fromLTWH(0, 776, 400, 24);
      expect(themeRevealCovers(bottom, origin, 260), isTrue);
      expect(themeRevealCovers(top, origin, 260), isFalse);
      expect(
        themeRevealCovers(top, origin, math.sqrt(200 * 200 + 650 * 650) + 1),
        isTrue,
      );
    },
  );
  test('invalid and outside coordinates do not animate', () {
    expect(
      themeRevealCanAnimate(const Size(400, 800), const Offset(20, 30)),
      isTrue,
    );
    expect(themeRevealCanAnimate(Size.zero, Offset.zero), isFalse);
    expect(
      themeRevealCanAnimate(const Size(400, 800), const Offset(-1, 0)),
      isFalse,
    );
    expect(
      themeRevealCanAnimate(const Size(400, 800), const Offset(double.nan, 30)),
      isFalse,
    );
  });
}
