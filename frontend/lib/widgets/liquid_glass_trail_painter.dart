import 'package:flutter/material.dart';

class LiquidGlassTrailPainter extends CustomPainter {
  final double progress;
  final double velocity;
  final Color color;
  final int itemCount;
  final bool reduceMotion;

  const LiquidGlassTrailPainter({
    required this.progress,
    required this.velocity,
    required this.color,
    required this.itemCount,
    this.reduceMotion = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount <= 0 || size.isEmpty) return;

    final cell = size.width / itemCount;
    final center = Offset((progress + .5) * cell, size.height / 2);
    const baseWidth = 48.0;
    const baseHeight = 28.0;
    final speed = (velocity.abs() * 16).clamp(0.0, 1.0);
    final direction = velocity == 0 ? 1.0 : velocity.sign;

    if (!reduceMotion && speed > .04) {
      final extension = 10 + 32 * speed;
      final left = direction > 0
          ? center.dx - baseWidth / 2 - extension
          : center.dx - baseWidth / 2 + 10;
      final right = direction > 0
          ? center.dx + baseWidth / 2 - 10
          : center.dx + baseWidth / 2 + extension;
      final smearRect = Rect.fromLTRB(
        left,
        center.dy - baseHeight * .38,
        right,
        center.dy + baseHeight * .38,
      );
      final smearPaint = Paint()
        ..shader = LinearGradient(
          begin: direction > 0 ? Alignment.centerLeft : Alignment.centerRight,
          end: direction > 0 ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            color.withAlpha(0),
            color.withAlpha((26 + 34 * speed).round()),
            Colors.white.withAlpha((20 + 24 * speed).round()),
          ],
          stops: const [0, .58, 1],
        ).createShader(smearRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(smearRect, const Radius.circular(18)),
        smearPaint,
      );
    }

    final baseRect = Rect.fromCenter(
      center: center,
      width: baseWidth + speed * 5,
      height: baseHeight,
    );
    final base = RRect.fromRectAndRadius(baseRect, const Radius.circular(16));
    canvas.drawRRect(
      base,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(118),
            color.withAlpha(42),
            Colors.white.withAlpha(72),
          ],
        ).createShader(baseRect),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withAlpha(145),
    );
  }

  @override
  bool shouldRepaint(covariant LiquidGlassTrailPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.velocity != velocity ||
        oldDelegate.color != color ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
