import 'schedule_plan.dart';

class NotificationAuditStore {
  NotificationAudit _last = const NotificationAudit(AuditState.disabled);
  DateTime? _nextAt;

  NotificationAudit get last => _last;
  DateTime? get nextAt => _nextAt;

  void record(NotificationAudit value, {DateTime? nextAt}) {
    _last = value;
    _nextAt = nextAt;
  }
}
