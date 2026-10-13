import 'dart:math' as math;
import 'package:flutter/material.dart';

bool themeRevealCanAnimate(Size size, Offset origin) =>
    size.width.isFinite &&
    size.height.isFinite &&
    !size.isEmpty &&
    origin.dx.isFinite &&
    origin.dy.isFinite &&
    (Offset.zero & size).contains(origin);

double themeRevealRadius(Size size, Offset origin) =>
    _cornerDistance(Offset.zero & size, origin) + 2;

double _cornerDistance(Rect rect, Offset origin) => [
  rect.topLeft,
  rect.topRight,
  rect.bottomLeft,
  rect.bottomRight,
].map((corner) => (corner - origin).distance).reduce(math.max);

bool themeRevealCovers(Rect region, Offset origin, double radius) =>
    region.isEmpty || radius >= _cornerDistance(region, origin);

Path themeRevealMask(Size size, Offset origin, double radius) {
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size);
  if (radius > 0) path.addOval(Rect.fromCircle(center: origin, radius: radius));
  return path;
}
