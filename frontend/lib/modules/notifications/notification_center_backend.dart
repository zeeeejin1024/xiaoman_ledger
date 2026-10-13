import '../../core/notification_coordinator.dart';
import '../../core/notification_models.dart';
import '../../core/notifications.dart';
import '../../core/notifications/schedule_plan.dart';

class NotificationCenterSnapshot {
  final NotificationPreferences settings;
  final bool permission;
  final AuditState dailyState;
  final DateTime? dailyNextAt;
  final Set<int>? pendingIds;
  const NotificationCenterSnapshot({
    required this.settings,
    required this.permission,
    required this.dailyState,
    this.dailyNextAt,
    this.pendingIds,
  });
}

/// Keeps system I/O separate from the page's loading/saving lifecycle.
abstract interface class NotificationCenterBackend {
  Future<NotificationCenterSnapshot> load({bool reconcile = true});
  Future<bool> save(NotificationPreferences settings);
}

class LocalNotificationCenterBackend implements NotificationCenterBackend {
  @override
  Future<NotificationCenterSnapshot> load({bool reconcile = true}) async {
    final coordinator = await NotificationCoordinator.shared();
    if (reconcile) await coordinator.reconcileAll();
    final permission = await NotificationService.isPermissionGranted();
    Set<int>? pending;
    try {
      pending = await NotificationService.pendingRequestIds();
    } catch (_) {
      // Unknown is different from an empty queue.
    }
    return NotificationCenterSnapshot(
      settings: coordinator.settings,
      permission: permission,
      dailyState: coordinator.dailyAudit.last.state,
      dailyNextAt: coordinator.dailyAudit.nextAt,
      pendingIds: pending,
    );
  }

  @override
  Future<bool> save(NotificationPreferences settings) async =>
      (await NotificationCoordinator.shared()).requestPermissionAndUpdate(
        settings,
      );
}
