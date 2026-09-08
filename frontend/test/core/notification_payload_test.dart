import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';

void main() {
  test('round trips a semantic notification payload', () {
    const original = NotificationPayload(
      type: 'deal',
      route: 'profile',
      entityId: 42,
    );

    final decoded = NotificationPayload.decode(original.encode());

    expect(decoded.version, 1);
    expect(decoded.type, 'deal');
    expect(decoded.route, 'profile');
    expect(decoded.entityId, 42);
  });

  test('malformed payload safely falls back to home', () {
    final decoded = NotificationPayload.decode('{not-json');

    expect(decoded, NotificationPayload.fallback);
    expect(decoded.route, 'home');
  });
}
