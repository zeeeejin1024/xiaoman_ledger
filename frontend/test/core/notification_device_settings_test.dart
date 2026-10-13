import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notification_device_settings.dart';

void main() {
  for (final manufacturer in [
    'xiaomi',
    'huawei',
    'honor',
    'oppo',
    'realme',
    'vivo',
    'iqoo',
    'samsung',
    'unknown',
  ]) {
    test('$manufacturer has a complete notification guide', () {
      final guide = NotificationDeviceGuide.fromManufacturer(manufacturer);
      expect(guide.brandName, isNotEmpty);
      expect(guide.steps.length, greaterThanOrEqualTo(3));
      expect(guide.fallback, isNotEmpty);
    });
  }
}
