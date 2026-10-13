import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';

void main() {
  test('distinguishes an empty queue from a failed queue query', () {
    expect(NotificationQueueState.ready(0).displayText, '0 条');
    expect(NotificationQueueState.unavailable.displayText, '暂不可用');
    expect(NotificationQueueState.ready(1).displayText, '1 条');
  });
}
