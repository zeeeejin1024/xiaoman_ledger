import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:xiaojia_ledger/core/theme.dart';
import 'brand_mark_geometry.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(
      size.width * BrandMarkGeometry.center,
      size.height * BrandMarkGeometry.center,
    );
    final stroke = shortest * BrandMarkGeometry.strokeWidth;
    final rect = Rect.fromCircle(
      center: center,
      radius: shortest * BrandMarkGeometry.radius,
    );
    final sweep =
        (math.pi * 2) -
        BrandMarkGeometry.gap +
        (math.sin(progress * math.pi) * BrandMarkGeometry.sweepAnimationDelta);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(
      rect,
      BrandMarkGeometry.startAngle,
      sweep,
      false,
      trackPaint,
    );

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, BrandMarkGeometry.startAngle, sweep, false, ringPaint);

    final markerAngle =
        BrandMarkGeometry.startAngle +
        sweep *
            (BrandMarkGeometry.markerProgress +
                progress * BrandMarkGeometry.markerProgressDelta);
    final markerCenter = Offset(
      center.dx + math.cos(markerAngle) * rect.width / 2,
      center.dy + math.sin(markerAngle) * rect.height / 2,
    );
    final markerPaint = Paint()..color = markerColor;
    canvas.drawCircle(
      markerCenter,
      shortest * BrandMarkGeometry.markerRadius,
      markerPaint,
    );

    final gapAngle =
        BrandMarkGeometry.startAngle +
        sweep +
        BrandMarkGeometry.gapMarkerAngleOffset;
    final gapCenter = Offset(
      center.dx + math.cos(gapAngle) * rect.width / 2,
      center.dy + math.sin(gapAngle) * rect.height / 2,
    );
    final gapPaint = Paint()..color = markerColor.withAlpha(210);
    canvas.drawCircle(
      gapCenter,
      shortest * BrandMarkGeometry.gapMarkerRadius,
      gapPaint,
    );

    final tickPaint = Paint()
      ..color = ringColor.withAlpha(105)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = shortest * BrandMarkGeometry.tickStrokeWidth;
    for (final tickProgress in BrandMarkGeometry.tickProgresses) {
      final tickAngle = BrandMarkGeometry.startAngle + sweep * tickProgress;
      final outer = Offset(
        center.dx +
            math.cos(tickAngle) * shortest * BrandMarkGeometry.tickOuterRadius,
        center.dy +
            math.sin(tickAngle) * shortest * BrandMarkGeometry.tickOuterRadius,
      );
      final inner = Offset(
        center.dx +
            math.cos(tickAngle) * shortest * BrandMarkGeometry.tickInnerRadius,
        center.dy +
            math.sin(tickAngle) * shortest * BrandMarkGeometry.tickInnerRadius,
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
