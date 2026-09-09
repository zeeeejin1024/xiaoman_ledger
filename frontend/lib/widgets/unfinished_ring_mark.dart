import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:xiaojia_ledger/core/theme.dart';

/// The small, open ring that anchors the Xiao Man visual language.
///
/// The animation is intentionally restrained: the opening stays visible while
/// a small marker travels along the accumulated arc. It reads as progress,
/// not as a loading spinner.
class UnfinishedRingMark extends StatefulWidget {
  final double size;
  final bool animate;
  final Color? ringColor;
  final Color? markerColor;
  final Color? trackColor;
  final String semanticLabel;

  const UnfinishedRingMark({
    super.key,
    this.size = 72,
    this.animate = true,
    this.ringColor,
    this.markerColor,
    this.trackColor,
    this.semanticLabel = '小满记账标志',
  });

  @override
  State<UnfinishedRingMark> createState() => _UnfinishedRingMarkState();
}

class _UnfinishedRingMarkState extends State<UnfinishedRingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant UnfinishedRingMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowAnimation =
        widget.animate &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final painter = (double progress) => _UnfinishedRingPainter(
      progress: progress,
      ringColor: widget.ringColor ?? AppColors.ink,
      markerColor: widget.markerColor ?? AppColors.highlight,
      trackColor: widget.trackColor ?? AppColors.ink.withAlpha(28),
    );

    return Semantics(
      container: true,
      image: true,
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: allowAnimation
            ? AnimatedBuilder(
                animation: _controller,
                builder: (_, _) =>
                    CustomPaint(painter: painter(_controller.value)),
              )
            : CustomPaint(painter: painter(0)),
      ),
    );
  }
}

class _UnfinishedRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color markerColor;
  final Color trackColor;

  const _UnfinishedRingPainter({
    required this.progress,
    required this.ringColor,
    required this.markerColor,
    required this.trackColor,
  });

  static const _startAngle = -math.pi / 2 + 0.18;
  static const _gap = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = shortest * 0.105;
    final rect = Rect.fromCircle(center: center, radius: shortest * 0.34);
    final sweep = (math.pi * 2) - _gap + (math.sin(progress * math.pi) * 0.08);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, _startAngle, sweep, false, trackPaint);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, _startAngle, sweep, false, ringPaint);

    final markerAngle = _startAngle + sweep * (0.55 + progress * 0.22);
    final markerCenter = Offset(
      center.dx + math.cos(markerAngle) * rect.width / 2,
      center.dy + math.sin(markerAngle) * rect.height / 2,
    );
    final markerPaint = Paint()..color = markerColor;
    canvas.drawCircle(markerCenter, shortest * 0.055, markerPaint);

    final gapAngle = _startAngle + sweep + 0.08;
    final gapCenter = Offset(
      center.dx + math.cos(gapAngle) * rect.width / 2,
      center.dy + math.sin(gapAngle) * rect.height / 2,
    );
    final gapPaint = Paint()..color = markerColor.withAlpha(210);
    canvas.drawCircle(gapCenter, shortest * 0.027, gapPaint);

    final tickPaint = Paint()
      ..color = ringColor.withAlpha(105)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = shortest * 0.025;
    for (var i = 0; i < 3; i++) {
      final tickAngle = _startAngle + sweep * (0.14 + i * 0.17);
      final outer = Offset(
        center.dx + math.cos(tickAngle) * shortest * 0.47,
        center.dy + math.sin(tickAngle) * shortest * 0.47,
      );
      final inner = Offset(
        center.dx + math.cos(tickAngle) * shortest * 0.42,
        center.dy + math.sin(tickAngle) * shortest * 0.42,
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UnfinishedRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.trackColor != trackColor;
  }
}
