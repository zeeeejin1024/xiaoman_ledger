import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/navigation_motion_controller.dart';

void main() {
  test('drag threshold accepts distance or velocity', () {
    expect(resolveTarget(origin: 1, progress: 1.19, velocity: 0), 2);
    expect(resolveTarget(origin: 1, progress: 1.05, velocity: 700), 2);
  });

  test('long swipe resolves to the furthest reachable destination', () {
    expect(resolveTarget(origin: 0, progress: 4.0, velocity: 0), 4);
    expect(resolveTarget(origin: 4, progress: 0.0, velocity: 0), 0);
  });
  test('controller retains continuous position', () async {
    final c = NavigationMotionController();
    c.dragTo(1.4);
    expect(c.position, 1.4);
    await c.animateTo(2);
    expect(c.position, 2);
  });
}
