import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaojia_ledger/core/theme.dart';

class _Particle {
  double x, y, dx, dy, radius, opacity;
  final Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.radius,
    required this.opacity,
    required this.color,
  });
}

class ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.opacity <= 0) continue;
      final paint = Paint()
        ..color = p.color.withAlpha((p.opacity * 255).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
      // 微发光
      if (p.opacity > 0.3) {
        final glowPaint = Paint()
          ..color = p.color.withAlpha((p.opacity * 60).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(p.x, p.y), p.radius * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter old) => true;
}

class ParticleEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final int particleCount;
  final Duration duration;
  const ParticleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.particleCount = 22,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<_Particle> _particles = [];
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.addListener(_tick);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _spawnParticles() {
    final rng = Random();
    final colors = [
      AppColors.premiumLight,
      AppColors.premium,
      AppColors.premiumDark,
      AppColors.highlight,
      AppColors.accent,
    ];
    _particles = List.generate(widget.particleCount, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 60 + rng.nextDouble() * 120;
      return _Particle(
        x: 0,
        y: 0,
        dx: cos(angle) * speed,
        dy: sin(angle) * speed - 40, // 向上偏移
        radius: 2 + rng.nextDouble() * 4,
        opacity: 0.7 + rng.nextDouble() * 0.3,
        color: colors[rng.nextInt(colors.length)],
      );
    });
    _ctrl.reset();
    _ctrl.forward();
  }

  void _tick() {
    final t = _ctrl.value;
    final dt = 0.016; // ~60fps
    for (final p in _particles) {
      p.x += p.dx * dt;
      p.dy += 200 * dt; // 重力
      p.y += p.dy * dt;
      p.opacity = (1 - t) * (0.7 + Random().nextDouble() * 0.3);
      p.radius *= 0.995;
    }
    if (mounted) setState(() {});
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _spawnParticles();
    setState(() => _animating = true);
    widget.onTap?.call();
    Future.delayed(widget.duration, () {
      if (mounted) setState(() => _animating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_animating && _particles.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: ParticlePainter(_particles)),
              ),
            ),
        ],
      ),
    );
  }
}
