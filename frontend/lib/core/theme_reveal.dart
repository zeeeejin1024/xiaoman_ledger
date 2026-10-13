import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'theme_reveal_geometry.dart';

typedef ThemeRevealCapture =
    Future<ui.Image> Function(
      RenderRepaintBoundary boundary,
      double pixelRatio,
    );
typedef ThemeRevealSave = Future<bool> Function(int index);

/// Routes and tabs share this cancellation path: never display a captured
/// page over a different route. The observer does not own theme state.
final themeRevealNavigationObserver = ThemeRevealNavigationObserver();

class ThemeRevealNavigationObserver extends NavigatorObserver {
  VoidCallback? onNavigation;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onNavigation?.call();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onNavigation?.call();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onNavigation?.call();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onNavigation?.call();
  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) => onNavigation?.call();
}

Future<bool> _saveTheme(int index) async =>
    (await SharedPreferences.getInstance()).setInt('color_scheme', index);

/// One real application tree, with a transient old-frame image above it.
/// Capture and saving are injectable platform dependencies for tests.
class ThemeReveal extends StatefulWidget {
  final Widget child;
  final ThemeRevealCapture? capture;
  final ThemeRevealSave? save;
  const ThemeReveal({super.key, required this.child, this.capture, this.save});

  static Future<bool> change(
    BuildContext context,
    AppColorScheme scheme,
    Offset globalOrigin,
  ) {
    final state = context.findAncestorStateOfType<_ThemeRevealState>();
    if (state != null) return state.change(scheme, globalOrigin);
    AppColors.apply(scheme);
    return _saveTheme(AppColorScheme.all.indexOf(scheme));
  }

  static void finish(BuildContext context) =>
      context.findAncestorStateOfType<_ThemeRevealState>()?.finish();

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _boundaryKey = GlobalKey();
  late final AnimationController _driver;
  late final CurvedAnimation _progress;
  Future<void> _work = Future.value();
  Future<bool> _writes = Future.value(true);
  int _generation = 0;
  _ThemeRequest? _latest;
  ui.Image? _image;
  Offset _origin = Offset.zero;
  Size _size = Size.zero;
  EdgeInsets _insets = EdgeInsets.zero;
  SystemUiOverlayStyle? _oldStyle;
  bool _revealing = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _driver = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _progress = CurvedAnimation(
      parent: _driver,
      curve: const Cubic(.25, 1, .5, 1),
    );
    _driver.addListener(_syncBarAppearance);
    WidgetsBinding.instance.addObserver(this);
    themeRevealNavigationObserver.onNavigation = finish;
  }

  Future<bool> _persist(AppColorScheme scheme) {
    final index = AppColorScheme.all.indexOf(scheme);
    _writes = _writes.then((_) async {
      try {
        return await (widget.save ?? _saveTheme)(index);
      } catch (_) {
        return false;
      }
    });
    return _writes;
  }

  Future<bool> change(AppColorScheme scheme, Offset globalOrigin) {
    if (_disposed) return Future.value(false);
    // A same-theme tap also cancels an outstanding selection of another
    // scheme, and retries persistence when a previous save failed.
    final generation = ++_generation;
    _clearVisual();
    final request = _ThemeRequest(generation, scheme, globalOrigin);
    _latest = request;
    if (identical(AppColors.scheme, scheme) ||
        MediaQuery.disableAnimationsOf(context)) {
      AppColors.apply(scheme);
      _latest = null;
      return _persist(scheme);
    }
    _work = _work.then((_) => _perform(request));
    return request.result.future;
  }

  bool _current(_ThemeRequest request) =>
      mounted && !_disposed && request.generation == _generation;

  Future<void> _perform(_ThemeRequest request) async {
    Future<bool>? saved;
    try {
      if (!_current(request)) return;
      final media = MediaQuery.of(context);
      await WidgetsBinding.instance.endOfFrame;
      if (!_current(request)) return;
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
        saved = _applyImmediately(request);
        return;
      }
      final size = boundary.size;
      final origin = boundary.globalToLocal(request.origin);
      if (!themeRevealCanAnimate(size, origin)) {
        saved = _applyImmediately(request);
        return;
      }
      // One capture at a time. Late results following cancellation are
      // disposed before installation; never retain a screenshot cache.
      final pixelRatio = math.min(media.devicePixelRatio, 2.0);
      ui.Image captured;
      var captureAbandoned = false;
      try {
        final pending =
            widget.capture?.call(boundary, pixelRatio) ??
            boundary.toImage(pixelRatio: pixelRatio);
        captured = await pending
            .then((image) {
              if (captureAbandoned) image.dispose();
              return image;
            })
            .timeout(
              const Duration(milliseconds: 300),
              onTimeout: () {
                captureAbandoned = true;
                throw TimeoutException('Theme capture unavailable');
              },
            );
      } catch (_) {
        if (_current(request)) saved = _applyImmediately(request);
        return;
      }
      if (!_current(request)) {
        captured.dispose();
        return;
      }
      _origin = origin;
      _size = size;
      _insets = media.viewPadding;
      _oldStyle = AppColors.systemUiOverlayStyle;
      _driver.value = 0;
      setState(() {
        _image = captured;
        _revealing = false;
      });
      // Paint the complete old image before changing the real page.
      await WidgetsBinding.instance.endOfFrame;
      if (!_current(request)) return;
      AppColors.systemUiOverride.value = _oldStyle;
      AppColors.apply(request.scheme);
      saved = request.persistence = _persist(request.scheme);
      await WidgetsBinding.instance.endOfFrame;
      if (!_current(request)) return;
      _revealing = true;
      await _driver.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Retargeting, navigation, lifecycle or resize finished the old reveal.
    } finally {
      if (_current(request)) {
        _latest = null;
        _clearVisual();
      }
      // Do not hold up the visual request queue on disk I/O.
      final result = saved ?? request.persistence;
      if (result != null) {
        result.then((value) {
          if (!request.result.isCompleted) request.result.complete(value);
        });
      } else if (!request.result.isCompleted) {
        request.result.complete(false);
      }
    }
  }

  Future<bool> _applyImmediately(_ThemeRequest request) {
    AppColors.apply(request.scheme);
    return request.persistence = _persist(request.scheme);
  }

  void _syncBarAppearance() {
    if (!_revealing || _image == null || _oldStyle == null) return;
    final target = AppColors.overlayForScheme(AppColors.scheme);
    final radius =
        20 + (themeRevealRadius(_size, _origin) - 20) * _progress.value;
    final topDone = themeRevealCovers(
      Rect.fromLTWH(0, 0, _size.width, _insets.top),
      _origin,
      radius,
    );
    final bottomDone = themeRevealCovers(
      Rect.fromLTWH(
        0,
        _size.height - _insets.bottom,
        _size.width,
        _insets.bottom,
      ),
      _origin,
      radius,
    );
    final top = topDone ? target : _oldStyle!;
    final bottom = bottomDone ? target : _oldStyle!;
    AppColors.systemUiOverride.value = target.copyWith(
      statusBarColor: top.statusBarColor,
      statusBarIconBrightness: top.statusBarIconBrightness,
      statusBarBrightness: top.statusBarBrightness,
      systemNavigationBarColor: bottom.systemNavigationBarColor,
      systemNavigationBarIconBrightness:
          bottom.systemNavigationBarIconBrightness,
      systemNavigationBarDividerColor: bottom.systemNavigationBarDividerColor,
    );
  }

  void _clearVisual() {
    _driver.stop(canceled: true);
    _revealing = false;
    AppColors.systemUiOverride.value = null;
    final previous = _image;
    _image = null;
    _oldStyle = null;
    if (previous != null) {
      if (mounted && !_disposed) setState(() {});
      // Raw painter can still be retained until the next frame. Dispose only
      // after removal has painted, not while it is referenced by the layer.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void finish() {
    if (_disposed || (_latest == null && _image == null)) return;
    final request = _latest;
    ++_generation;
    _latest = null;
    _clearVisual();
    if (request != null) {
      AppColors.apply(request.scheme);
      final saved = request.persistence ??= _persist(request.scheme);
      saved.then((ok) {
        if (!request.result.isCompleted) request.result.complete(ok);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) finish();
  }

  @override
  void didChangeMetrics() => finish();
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    final latest = _latest;
    if (latest != null && !latest.result.isCompleted) {
      latest.result.complete(false);
    }
    WidgetsBinding.instance.removeObserver(this);
    if (themeRevealNavigationObserver.onNavigation == finish) {
      themeRevealNavigationObserver.onNavigation = null;
    }
    _clearVisual();
    _progress.dispose();
    _driver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) finish();
          return false;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(key: _boundaryKey, child: widget.child),
            if (_image case final image?)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('theme-reveal-mask'),
                        painter: _ThemeRevealPainter(
                          image,
                          _origin,
                          _progress,
                          () => _revealing,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _ThemeRequest {
  final int generation;
  final AppColorScheme scheme;
  final Offset origin;
  final result = Completer<bool>();
  Future<bool>? persistence;
  _ThemeRequest(this.generation, this.scheme, this.origin);
}

class _ThemeRevealPainter extends CustomPainter {
  final ui.Image image;
  final Offset origin;
  final Animation<double> progress;
  final bool Function() revealing;
  _ThemeRevealPainter(this.image, this.origin, this.progress, this.revealing)
    : super(repaint: progress);
  @override
  void paint(Canvas canvas, Size size) {
    final radius = revealing()
        ? 20 + (themeRevealRadius(size, origin) - 20) * progress.value
        : 0.0;
    canvas.save();
    canvas.clipPath(themeRevealMask(size, origin, radius));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThemeRevealPainter old) =>
      image != old.image || origin != old.origin;
}
