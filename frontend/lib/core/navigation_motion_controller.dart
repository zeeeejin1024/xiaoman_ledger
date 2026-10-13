import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

int resolveTarget({
  required int origin,
  required double progress,
  required double velocity,
  int maxIndex = 4,
}) {
  final distance = (progress - origin).abs();
  final target = distance < .18 && velocity.abs() >= 500
      ? origin + (velocity > 0 ? 1 : -1)
      : distance >= .18
      ? origin + (progress >= origin ? distance.ceil() : -distance.ceil())
      : origin;
  return target.clamp(0, maxIndex);
}

class NavigationMotionController extends ChangeNotifier {
  final AnimationController? _driver;
  final bool reduceMotion;
  Animation<double>? _animation;
  double position;
  double velocity = 0;

  NavigationMotionController({
    this.position = 0,
    TickerProvider? vsync,
    this.reduceMotion = false,
  }) : _driver = vsync == null
           ? null
           : AnimationController(
               vsync: vsync,
               duration: reduceMotion
                   ? const Duration(milliseconds: 120)
                   : const Duration(milliseconds: 220),
             );

  void dragTo(double value) {
    _driver?.stop();
    final previous = position;
    if (value < 0) {
      position = value * .28;
    } else if (value > 4) {
      position = 4 + (value - 4) * .28;
    } else {
      position = value;
    }
    velocity = position - previous;
    notifyListeners();
  }

  Future<void> animateTo(int target) async {
    final end = target.toDouble().clamp(0.0, 4.0).toDouble();
    final driver = _driver;
    if (driver == null) {
      velocity = end - position;
      position = end;
      notifyListeners();
      return;
    }
    driver.stop();
    final start = position;
    _animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: driver, curve: const Cubic(.25, 1, .5, 1)),
    );
    void tick() {
      final previous = position;
      position = _animation!.value;
      velocity = position - previous;
      notifyListeners();
    }

    _animation!.addListener(tick);
    try {
      await driver.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A new target intentionally interrupted this animation.
    } finally {
      _animation?.removeListener(tick);
    }
    velocity = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _driver?.dispose();
    super.dispose();
  }
}
