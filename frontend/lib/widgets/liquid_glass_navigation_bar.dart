import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaojia_ledger/core/navigation_motion_controller.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/widgets/liquid_glass_trail_painter.dart';

class LiquidGlassNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final NavigationMotionController controller;
  final List<NavigationDestination> destinations;

  const LiquidGlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.controller,
    required this.destinations,
  });

  @override
  State<LiquidGlassNavigationBar> createState() =>
      _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar> {
  int? _lastCrossed;

  void _drag(DragUpdateDetails details) {
    final cell = MediaQuery.sizeOf(context).width / widget.destinations.length;
    widget.controller.dragTo(
      widget.controller.position + details.delta.dx / cell,
    );
    final crossed = widget.controller.position.round().clamp(
      0,
      widget.destinations.length - 1,
    );
    if (_lastCrossed != crossed) {
      _lastCrossed = crossed;
      HapticFeedback.selectionClick();
    }
  }

  void _end(DragEndDetails details) {
    final target = resolveTarget(
      origin: widget.selectedIndex,
      progress: widget.controller.position,
      velocity: details.primaryVelocity ?? 0,
      maxIndex: widget.destinations.length - 1,
    );
    widget.onSelected(target);
    _lastCrossed = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.navBg),
        child: GestureDetector(
          key: const ValueKey('tab-gesture-surface'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _drag,
          onHorizontalDragEnd: _end,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (_, _) => Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 2,
                  height: 38,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: LiquidGlassTrailPainter(
                          progress: widget.controller.position.clamp(
                            0,
                            widget.destinations.length - 1,
                          ),
                          velocity: widget.controller.velocity,
                          color: colors.primary,
                          itemCount: widget.destinations.length,
                          reduceMotion: MediaQuery.disableAnimationsOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  currentIndex: widget.selectedIndex,
                  onTap: (index) {
                    HapticFeedback.selectionClick();
                    widget.onSelected(index);
                  },
                  items: widget.destinations
                      .map(
                        (destination) => BottomNavigationBarItem(
                          icon: destination.icon,
                          activeIcon: destination.selectedIcon,
                          label: destination.label,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
