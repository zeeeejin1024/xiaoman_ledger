import 'package:flutter/material.dart';

typedef LazyTabBuilder = Widget Function(BuildContext context);

class LazyTabHost extends StatefulWidget {
  final int index;
  final List<LazyTabBuilder> builders;
  final Duration transitionDuration;

  const LazyTabHost({
    super.key,
    required this.index,
    required this.builders,
    this.transitionDuration = const Duration(milliseconds: 180),
  });

  @override
  State<LazyTabHost> createState() => _LazyTabHostState();
}

class _LazyTabHostState extends State<LazyTabHost> {
  final Map<int, Widget> _pages = <int, Widget>{};

  void _ensureCurrentPage() {
    assert(widget.builders.isNotEmpty);
    assert(widget.index >= 0 && widget.index < widget.builders.length);
    _pages.putIfAbsent(
      widget.index,
      () => KeyedSubtree(
        key: PageStorageKey<int>(widget.index),
        child: widget.builders[widget.index](context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureCurrentPage();
    final indices = _pages.keys.toList()..sort();

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final index in indices) _buildLayer(index, _pages[index]!),
      ],
    );
  }

  Widget _buildLayer(int index, Widget child) {
    final active = index == widget.index;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: Offstage(
            offstage: !active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: widget.transitionDuration,
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: active ? Offset.zero : const Offset(0, 0.012),
                duration: widget.transitionDuration,
                curve: Curves.easeOutCubic,
                child: TickerMode(enabled: active, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
